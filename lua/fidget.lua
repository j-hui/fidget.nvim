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
  for _, fidget in pairs(fidgets) do
    offset = offset + fidget:show(offset)
  end
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
  local col = options.align.right and api.nvim_win_get_width(0) or 1
  local row = options.align.bottom and (api.nvim_win_get_height(0) - offset)
    or (1 + offset)
  local anchor = (options.align.bottom and "S" or "N")
    .. (options.align.right and "E" or "W")

  if self.bufid == nil or not api.nvim_buf_is_valid(self.bufid) then
    self.bufid = api.nvim_create_buf(false, true)
  end
  if self.winid == nil or not api.nvim_win_is_valid(self.winid) then
    self.winid = api.nvim_open_win(self.bufid, false, {
      relative = "win",
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
      focusable = false,
      style = "minimal",
      noautocmd = true,
    })
  else
    api.nvim_win_set_config(self.winid, {
      win = api.nvim_get_current_win(),
      relative = "win",
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
    })
  end

  api.nvim_win_set_option(self.winid, "winblend", 100) -- Make transparent
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
  for _, _ in pairs(self.tasks) do
    return true
  end
  return false
end

function base_fidget:spin()
  if options.timer.spinner_rate > 0 then
    vim.defer_fn(function()
      if self:has_tasks() then
        self.spinner_idx = (self.spinner_idx + 1) % #options.text.spinner
        self:spin()
      else
        self.spinner_idx = -1
        self:kill()
      end
      self:fmt()
    end, options.timer.spinner_rate)
  end
end

function base_fidget:kill()
  local function do_kill()
    if self:has_tasks() then -- double check, in case new tasks have started
      self:spin()
    else
      fidgets[self.key] = nil
      api.nvim_win_close(self.winid, true)
      api.nvim_buf_delete(self.bufid, { force = true })
      render_fidgets()
    end
  end

  if options.timer.fidget_decay > 0 then
    vim.defer_fn(do_kill, options.timer.fidget_decay)
  elseif options.timer.fidget_decay == 0 then
    do_kill()
  end
end

local function new_fidget(key, name)
  local fidget = vim.tbl_extend(
    "force",
    base_fidget,
    { key = key, name = name }
  )
  fidget:spin()
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
  local client_key = tostring(info.client_id)

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
