local api = vim.api
-- local log = require("fidget.log")

local fidget = {}
local options = {
  message = {
    commenced = "Started",
    completed = "Completed",
  },
  leftalign = false,
  topalign = false,
  fmt = {
    leftpad = true,
    task = function(task_name, message, percentage)
      return string.format(
        "%s%s [%s]",
        message,
        percentage and string.format(" (%s%%)", percentage) or "",
        task_name
      )
    end,
    widget = function(widget_name, spinner)
      -- return string.format("%s %s", spinner, widget_name)
      return string.format("%s %s", widget_name, spinner)
    end,
    -- spinner = { "▙", "▛", "▜", "▟" },
    spinner = {'⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'},
    -- Lots of fancy spinners here:
    -- https://github.com/sindresorhus/cli-spinners/blob/main/spinners.json
    done = "✔",
  },
  timer = {
    task_decay = 1000,
    spinner_rate = 125,
    widget_decay = 2000,
  },
}

local widgets = {}

local function render_widgets()
  local offset = 0
  for _, widget in pairs(widgets) do
    offset = offset + widget:show(offset)
  end
end

local base_widget = {
  key = nil,
  name = nil,
  bufid = nil,
  winid = nil,
  tasks = {},
  lines = {},
  spinner_idx = 0,
  max_line_len = 0,
}

function base_widget:fmt()
  local line = options.fmt.widget(self.name,
    self.spinner_idx == -1 and options.fmt.done
                           or options.fmt.spinner[self.spinner_idx + 1])
  self.lines = { line }
  self.max_line_len = #line
  for _, task in pairs(self.tasks) do
    line = options.fmt.task(task.title, task.message, task.percentage)
    table.insert(self.lines, line)
    self.max_line_len = math.max(self.max_line_len, #line)
  end
  if options.fmt.leftpad then
    local pad = "%"..tostring(self.max_line_len).."s"
    for i, _ in ipairs(self.lines) do
      self.lines[i] = string.format(pad, self.lines[i])
    end
  end
  render_widgets()
end

function base_widget:show(offset)
  local height = #self.lines
  local width = self.max_line_len
  local col = options.leftalign and 1 or api.nvim_win_get_width(0)
  local row = options.topalign and (1 + offset)
                               or (api.nvim_win_get_height(0) - offset)
  local anchor = (options.topalign and "N" or "S") ..
                 (options.leftalign and "W" or "E")

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

  api.nvim_buf_set_lines(self.bufid, 0, height, false, self.lines)

  return #self.lines + offset
end

function base_widget:kill_task(task)
  self.tasks[task] = nil
  self:fmt()
end

function base_widget:has_tasks()
  for _, _ in pairs(self.tasks) do
    return true
  end
  return false
end

function base_widget:spin()
  vim.defer_fn(function ()
    if self:has_tasks() then
      self.spinner_idx = (self.spinner_idx + 1) % #options.fmt.spinner
      self:spin()
    else
      self.spinner_idx = -1
      self:kill()
    end
    self:fmt()
  end, options.timer.spinner_rate)
end

function base_widget:kill()
  vim.defer_fn(function ()
    if self:has_tasks() then -- double check
      self:spin()
    else
      widgets[self.key] = nil
      api.nvim_win_close(self.winid, true)
      api.nvim_buf_delete(self.bufid, { force = true })
      render_widgets()
    end
  end, options.timer.widget_decay)
end

local function new_widget(key, name)
  local widget = vim.tbl_extend("force", base_widget, { key = key, name = name })
  widget:spin()
  return widget
end

local function new_task()
  return { title = nil, message = nil, percentage = nil }
end

local function handle_progress(_, msg, info)
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
  -- https://github.com/arkav/lualine-lsp-progress/blob/master/lua/lualine/components/lsp_progress.lua#L73
  -- TODO: copy from ts context: https://github.com/romgrk/nvim-treesitter-context/blob/b7d7aba81683c1cd76141e090ff335bb55332cba/lua/treesitter-context.lua#L269

  local task = msg.token
  local val = msg.value
  local client_key = tostring(info.client_id)

  if not task then
    return
  end

  -- Create entry if missing
  if widgets[client_key] == nil then
    widgets[client_key] = new_widget(
      client_key,
      vim.lsp.get_client_by_id(info.client_id).name
    )
  end
  local widget = widgets[client_key]
  if widget.tasks[task] == nil then
    widget.tasks[task] = new_task()
  end

  local progress = widget.tasks[task]

  -- Update progress state
  if val.kind == "begin" then
    progress.title = val.title
    progress.message = options.message.commenced
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
    progress.message = options.message.completed
    vim.defer_fn(function()
      widget:kill_task(task)
      end, options.timer.task_decay)
  end

  widget:fmt()
end

function fidget.setup(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})
  vim.lsp.handlers["$/progress"] = handle_progress
end

return fidget
