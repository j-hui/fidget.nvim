local M = {}
local api = vim.api
local log = require("fidget.log")

-- NOTE:
-- Workaround for nvim bug where nvim_win_set_option "leaks" local
-- options to windows created afterwards (thanks @sindrets!)
-- SEE:
-- https://github.com/b0o/incline.nvim/issues/4
-- https://github.com/neovim/neovim/issues/18283
-- https://github.com/neovim/neovim/issues/14670
local win_set_local_options = function(win, opts)
  api.nvim_win_call(win, function()
    for opt, val in pairs(opts) do
      local arg
      if type(val) == "boolean" then
        arg = (val and "" or "no") .. opt
      else
        arg = opt .. "=" .. val
      end
      vim.cmd("setlocal " .. arg)
    end
  end)
end

local options = {
  text = {
    spinner = "pipe",
    done = "✔",
    commenced = "Started",
    completed = "Completed",
  },
  align = {
    bottom = true,
    right = true,
  },
  window = {
    relative = "win",
    blend = 100,
    zindex = nil,
  },
  timer = {
    spinner_rate = 125,
    fidget_decay = 2000,
    task_decay = 1000,
  },
  fmt = {
    leftpad = true,
    stack_upwards = true,
    max_width = 0,
    fidget = function(fidget_name, spinner)
      return string.format("%s %s", spinner, fidget_name)
    end,
    task = function(task_name, message, percentage)
      return string.format(
        "%s%s [%s]",
        message,
        percentage and string.format(" (%.0f%%)", percentage) or "",
        task_name
      )
    end,
  },
  sources = {},
  debug = {
    logging = false,
    strict = false,
  },
}

local fidgets = {}


local function ignore_E523(callable)
  -- Wrap a function and suppress the E523 error.
  --
  -- The E523 error (Not allowed here) happens when 'secure' operations
  -- (including buffer or window management) are invoked while textlock is held
  -- or the neovim UI is blocking. They are not easily avoidable despite
  -- the use of vim.schedule (see #68 for more details).
  --
  -- This utility provides a workaround to simply supress the error.
  -- All other errors will be re-thrown.

  return function()
    status, ex = pcall(callable)
    if not status then  -- exception!
      if string.find(ex, "E523: Not allowed here") then
        -- Ignore E523 error (not allowed here): see #68
      else
        error("Error occured:\n" .. ex)
      end
    end
  end
end

local render_fidgets = ignore_E523(function()
  local offset = 0
  for client_id, fidget in pairs(fidgets) do
    if vim.lsp.buf_is_attached(0, client_id) then
      offset = offset + fidget:show(offset)
    else
      fidget:close()
    end
  end
end)

local function get_window_position(offset)
  local width, height, baseheight
  if options.window.relative == "editor" then
    local statusline_height = 0
    local laststatus = vim.opt.laststatus:get()
    if
      laststatus == 2
      or laststatus == 3
      or (laststatus == 1 and #api.nvim_tabpage_list_wins() > 1)
    then
      statusline_height = 1
    end

    height = vim.opt.lines:get() - (statusline_height + vim.opt.cmdheight:get())

    -- Does not account for &signcolumn or &foldcolumn, but there is no amazing way to get the
    -- actual "viewable" width of the editor
    --
    -- However, I cannot imagine that many people will render fidgets on the left side of their
    -- editor as it will more often overlay text
    width = vim.opt.columns:get()

    -- Applies when the layout is anchored at the top, need to check &tabline height
    baseheight = 0
    if options.window.relative == "editor" then
      local showtabline = vim.opt.showtabline:get()
      if
        showtabline == 2
        or (showtabline == 1 and #api.nvim_list_tabpages() > 1)
      then
        baseheight = 1
      end
    end
  else -- fidget relative to window.
    height = api.nvim_win_get_height(0)
    width = api.nvim_win_get_width(0)

    if vim.fn.exists("+winbar") > 0 and vim.opt.winbar:get() ~= "" then
      -- When winbar is enabled, the effective window height should be
      -- decreased by 1. (see :help winbar)
      height = height - 1
    end

    baseheight = 1
  end

  -- returns row, col
  return options.align.bottom and (height - offset) or (baseheight + offset),
    options.align.right and width or 1
end

local base_fidget = {
  key = nil,
  name = nil,
  bufid = nil,
  winid = nil,
  tasks = {},
  lines = {},
  spinner_idx = 0,
  max_line_len = 0,
  closed = false,
}

function base_fidget:fmt()
  -- Substitute tabs into spaces, to make strlen easier to count.
  local function subtab(s)
    return s and s:gsub("\t", "  ") or nil
  end
  local strlen = vim.fn.strdisplaywidth

  local line = options.fmt.fidget(
    self.name,
    self.spinner_idx == -1 and options.text.done
      or options.text.spinner[self.spinner_idx + 1]
  )
  self.lines = { line }
  self.max_line_len = strlen(line)
  for _, task in pairs(self.tasks) do
    line = options.fmt.task
      and options.fmt.task(
        subtab(task.title),
        subtab(task.message),
        task.percentage
      )
    if line then
      if options.fmt.stack_upwards then
        table.insert(self.lines, 1, line)
      else
        table.insert(self.lines, line)
      end
      self.max_line_len = math.max(self.max_line_len, strlen(line))
    end
  end

  -- Never try to output any text wider than what we are aligning to.
  self.max_line_len = math.min(
    self.max_line_len,
    options.window.relative == "editor" and vim.opt.columns:get()
      or api.nvim_win_get_width(0)
  )

  if options.fmt.max_width > 0 then
    self.max_line_len = math.min(self.max_line_len, options.fmt.max_width)
  end

  for i, s in ipairs(self.lines) do
    if strlen(s) > self.max_line_len then
      -- truncate
      self.lines[i] = vim.fn.strcharpart(s, 0, self.max_line_len - 1) .. "…"
    elseif options.fmt.leftpad then
      -- pad
      self.lines[i] = string.rep(" ", self.max_line_len - strlen(s)) .. s
    end
  end

  render_fidgets()
end

local function splits_on_newlines(lines)
  local result = {}
  for _, line in ipairs(lines) do
    if line:match("\n") then
      for _, subline in ipairs(vim.split(line, "\n")) do
        table.insert(result, subline)
      end
    else
      table.insert(result, line)
    end
  end
  return result
end

function base_fidget:show(offset)
  local height = #self.lines
  local width = self.max_line_len

  if height == 0 or width == 0 then
    -- Nothing to show
    self:close()
    return offset
  end

  local row, col = get_window_position(offset)
  local anchor = (options.align.bottom and "S" or "N")
    .. (options.align.right and "E" or "W")

  if self.bufid == nil or not api.nvim_buf_is_valid(self.bufid) then
    self.bufid = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(self.bufid, "filetype", "fidget")
  end
  if self.winid == nil or not api.nvim_win_is_valid(self.winid) then
    self.winid = api.nvim_open_win(self.bufid, false, {
      relative = options.window.relative,
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
      focusable = false,
      style = "minimal",
      zindex = options.window.zindex,
      noautocmd = true,
    })
  else
    api.nvim_win_set_config(self.winid, {
      win = options.window.relative == "win" and api.nvim_get_current_win()
        or nil,
      relative = options.window.relative,
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
      zindex = options.window.zindex,
    })
  end

  win_set_local_options(self.winid, {
    winblend = options.window.blend,
    winhighlight = "Normal:FidgetTask",
  })
  self.lines = splits_on_newlines(self.lines) -- handle lines that might contain a "\n" character
  api.nvim_buf_set_lines(self.bufid, 0, height, false, self.lines)
  if options.fmt.stack_upwards then
    api.nvim_buf_add_highlight(self.bufid, -1, "FidgetTitle", height - 1, 0, -1)
  else
    api.nvim_buf_add_highlight(self.bufid, -1, "FidgetTitle", 0, 0, -1)
  end

  return #self.lines + offset
end

function base_fidget:kill_task(task)
  self.tasks[task] = nil
  self:fmt()
end

function base_fidget:has_tasks()
  return next(self.tasks)
end

function base_fidget:close()
  -- NOTE: this function is not reentrant, and may be the source of silly races.
  -- Time will tell.

  if self.winid ~= nil and api.nvim_win_is_valid(self.winid) then
    api.nvim_win_hide(self.winid)
    self.winid = nil
  end
  if self.bufid ~= nil and api.nvim_buf_is_valid(self.bufid) then
    api.nvim_buf_delete(self.bufid, { force = true })
    self.bufid = nil
  end

  -- Remove a fidget after window/buffer deletion is successful (see #68)
  fidgets[self.key] = nil
  self.closed = true
end

function base_fidget:spin()
  local function do_spin(idx, continuation, delay)
    self.spinner_idx = idx
    self:fmt()
    vim.defer_fn(continuation, delay)
  end

  local function do_kill()
    ignore_E523(function()
      self:close()
      render_fidgets()
    end)()
  end

  local function spin_again()
    self:spin()
  end

  if self.closed then
    return
  end

  if self:has_tasks() then
    local next_idx = (self.spinner_idx + 1) % #options.text.spinner
    do_spin(next_idx, spin_again, options.timer.spinner_rate)
  else
    if options.timer.fidget_decay > 0 then
      -- kill later; indicate done for now
      do_spin(-1, function()
        if self:has_tasks() then
          do_spin(0, spin_again, options.timer.spinner_rate)
        else
          do_kill()
        end
      end, options.timer.fidget_decay)
    else
      -- kill now
      do_kill()
    end
  end
end

local function new_fidget(key, name)
  local fidget = vim.tbl_extend(
    "force",
    vim.deepcopy(base_fidget),
    { key = key, name = name }
  )
  if options.timer.spinner_rate > 0 then
    vim.defer_fn(function()
      fidget:spin()
    end, options.timer.spinner_rate)
  end
  return fidget
end

local function new_task()
  return { title = nil, message = nil, percentage = nil }
end

local function handle_progress(err, msg, info)
  -- See: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress

  log.debug(
    "Received progress notification:",
    { err = err, msg = msg, info = info }
  )

  local task = msg.token
  local val = msg.value

  if not task then
    -- Notification missing required token??
    return
  end

  local client_key = info.client_id
  local client = vim.lsp.get_client_by_id(info.client_id)
  if not client then
    return
  end
  local client_name = client.name

  if options.sources[client_name] and options.sources[client_name].ignore then
    return
  end

  -- Create entry if missing
  if fidgets[client_key] == nil then
    fidgets[client_key] = new_fidget(client_key, client_name)
  end
  local fidget = fidgets[client_key]
  if fidget.tasks[task] == nil then
    fidget.tasks[task] = new_task()
  end

  local progress = fidget.tasks[task]

  -- Update progress state
  if val.kind == "begin" then
    progress.title = val.title
    progress.message = options.text.commenced
  elseif val.kind == "report" then
    if val.percentage then
      progress.percentage = val.percentage
    end
    if val.message then
      progress.message = val.message
    end
  elseif val.kind == "end" then
    if progress.percentage then
      progress.percentage = 100
    end
    progress.message = options.text.completed
    if options.timer.task_decay > 0 then
      vim.defer_fn(function()
        fidget:kill_task(task)
      end, options.timer.task_decay)
    elseif options.timer.task_decay == 0 then
      fidget:kill_task(task)
    end
  else
    if options.debug.strict then
      log.warn(
        string.format(
          "Invalid progress notification from %s, unrecognized 'kind': %s",
          client_name,
          msg
        )
      )
    else
      fidget:kill_task(task)
    end
  end

  vim.schedule(function()
    fidget:fmt()
  end)
end

function M.is_installed()
  return vim.lsp.handlers["$/progress"] == handle_progress
end

function M.get_fidgets()
  local clients = {}
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    table.insert(clients, client.name)
  end
  return clients
end

function M.close(...)
  local args = { n = select("#", ...), ... }
  local function do_close(client_id)
    if fidgets[client_id] ~= nil then
      fidgets[client_id]:close()
    end
  end

  if args.n == 0 then
    for client_id, _ in pairs(fidgets) do
      do_close(client_id)
    end
  else
    for i = 1, args.n do
      do_close(args[i])
    end
  end

  render_fidgets()
end

function M.setup(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})

  if options.debug.logging then
    log.new({ level = "debug" }, true)
  end

  if type(options.text.spinner) == "string" then
    local spinner = require("fidget.spinners")[options.text.spinner]
    if spinner == nil then
      error("Unknown spinner name: " .. options.text.spinner)
    end
    options.text.spinner = spinner
  end

  if vim.lsp.handlers["$/progress"] then
     local old_handler = vim.lsp.handlers["$/progress"]
     vim.lsp.handlers["$/progress"] = function(...)
       old_handler(...)
       handle_progress(...)
     end
  else
     vim.lsp.handlers["$/progress"] = handle_progress
  end

  vim.cmd([[highlight default link FidgetTitle Title]])
  vim.cmd([[highlight default link FidgetTask NonText]])

  vim.cmd([[
    function! FidgetComplete(lead, cmd, cursor)
      return luaeval('require"fidget".get_fidgets()')
    endfunction
    command! -nargs=* -complete=customlist,FidgetComplete FidgetClose lua require'fidget'.close(<f-args>)
  ]])
end

return M
