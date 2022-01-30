local M = {}
local api = vim.api
local log = require("fidget.log")

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
    fidget = function(fidget_name, spinner)
      return string.format("%s %s", spinner, fidget_name)
    end,
    task = function(task_name, message, percentage)
      return string.format(
        "%s%s [%s]",
        message,
        percentage and string.format(" (%s%%)", percentage) or "",
        task_name
      )
    end,
  },
  debug = {
    logging = false,
  },
}

local fidgets = {}

local function render_fidgets()
  local offset = 0
  for client_id, fidget in pairs(fidgets) do
    if vim.lsp.buf_is_attached(0, client_id) then
      offset = offset + fidget:show(offset)
    else
      fidget:close()
    end
  end
end

local function get_window_position(offset)
  local width, height, baseheight
  if options.window.relative == "editor" then
    local statusline_height = 0
    local laststatus = vim.opt.laststatus:get()
    if
      laststatus == 2
      or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins() > 1)
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
        or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
      then
        baseheight = 1
      end
    end
  else
    height = api.nvim_win_get_height(0)
    width = api.nvim_win_get_width(0)
    baseheight = 1
  end

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
}

function base_fidget:fmt()
  local line = options.fmt.fidget(
    self.name,
    self.spinner_idx == -1 and options.text.done
      or options.text.spinner[self.spinner_idx + 1]
  )
  self.lines = { line }
  self.max_line_len = #line
  for _, task in pairs(self.tasks) do
    line = options.fmt.task(task.title, task.message, task.percentage)
    if options.fmt.stack_upwards then
      table.insert(self.lines, 1, line)
    else
      table.insert(self.lines, line)
    end
    self.max_line_len = math.max(self.max_line_len, #line)
  end

  -- Never try to output any text wider than the width of the current window
  -- Also, Lua's string.format does not seem to support any %Ns format specifier
  -- where n > 99, so we cap it here.
  self.max_line_len = math.min(self.max_line_len, api.nvim_win_get_width(0), 99)

  local pad = "%" .. tostring(self.max_line_len) .. "s"
  local trunc = "%." .. tostring(self.max_line_len) - 3 .. "s..."

  if options.fmt.leftpad then
    for i, _ in ipairs(self.lines) do
      if #self.lines[i] > self.max_line_len then
        self.lines[i] = string.format(trunc, self.lines[i])
      else
        self.lines[i] = string.format(pad, self.lines[i])
      end
    end
  else
    for i, _ in ipairs(self.lines) do
      if #self.lines[i] > self.max_line_len then
        self.lines[i] = string.format(trunc, self.lines[i])
      end
    end
  end

  render_fidgets()
end

function base_fidget:show(offset)
  local height = #self.lines
  local width = self.max_line_len
  local row, col = get_window_position(offset)
  local anchor = (options.align.bottom and "S" or "N")
    .. (options.align.right and "E" or "W")

  if self.bufid == nil or not api.nvim_buf_is_valid(self.bufid) then
    self.bufid = api.nvim_create_buf(false, true)
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

  api.nvim_win_set_option(self.winid, "winblend", options.window.blend)
  api.nvim_win_set_option(self.winid, "winhighlight", "Normal:FidgetTask")
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
  if self.winid ~= nil and api.nvim_win_is_valid(self.winid) then
    api.nvim_win_close(self.winid, true)
    self.winid = nil
  end
  if self.bufid ~= nil and api.nvim_buf_is_valid(self.bufid) then
    api.nvim_buf_delete(self.bufid, { force = true })
    self.bufid = nil
  end
end

function base_fidget:spin()
  local function do_spin(idx, continuation, delay)
    self.spinner_idx = idx
    self:fmt()
    vim.defer_fn(continuation, delay)
  end

  local function do_kill()
    self:close()
    fidgets[self.key] = nil
    render_fidgets()
  end

  local function spin_again()
    self:spin()
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
  local client_key = info.client_id

  if not task then
    return
  end

  -- Create entry if missing
  if fidgets[client_key] == nil then
    fidgets[client_key] = new_fidget(
      client_key,
      vim.lsp.get_client_by_id(info.client_id).name
    )
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
  end

  fidget:fmt()
end

function M.is_installed()
  return vim.lsp.handlers["$/progress"] == handle_progress
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

  vim.lsp.handlers["$/progress"] = handle_progress
  vim.cmd([[highlight default link FidgetTitle Title]])
  vim.cmd([[highlight default link FidgetTask NonText]])
end

return M
