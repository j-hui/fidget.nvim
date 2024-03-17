--- This module encapsulates state and helper functions associated with managing
--- nvim buffers and windows that are used to display notifications.
---
--- Not part of the public API (but do what you want with it).
---
--- If this framework were to be expanded to support multiple concurrent
--- windows, this module's contents would need to be cloned.
---
--- Note that for now, it only supports editor-relative floats, though some code
--- ported from the legacy version still supports window-relative floats.
local M = {}

---@options notification.window [[
---@protected
--- Notifications window options
M.options = {
  --- Base highlight group in the notification window
  ---
  --- Used by any Fidget notification text that is not otherwise highlighted,
  --- i.e., message text.
  ---
  --- Note that we use this blanket highlight for all messages to avoid adding
  --- separate highlights to each line (whose lengths may vary).
  ---
  --- Set to empty string to keep your theme defaults.
  ---
  --- With `winblend` set to anything less than `100`, this will also affect the
  --- background color in the notification box area (see `winblend` docs).
  ---
  ---@type string
  normal_hl = "Comment",

  --- Background color opacity in the notification window
  ---
  --- Note that the notification window is rectangular, so any cells covered by
  --- that rectangular area is affected by the background color of `normal_hl`.
  --- With `winblend` set to anything less than `100`, the background of
  --- `normal_hl` will be blended with that of whatever is underneath,
  --- including, e.g., a shaded `colorcolumn`, which is usually not desirable.
  ---
  --- However, if you would like to display the notification window as its own
  --- "boxed" area (especially if you are using a non-"none" `border`), you may
  --- consider setting `winblend` to something less than `100`.
  ---
  --- See also: options for |nvim_open_win()|
  ---
  ---@type number
  winblend = 100,

  --- Border around the notification window
  ---
  --- See also: options for |nvim_open_win()|
  ---
  ---@type "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[]
  border = "none",

  --- Highlight group for notification window border
  ---
  --- Set to empty string to keep your theme's default `FloatBorder` highlight.
  ---
  ---@type string
  border_hl = "",

  --- Stacking priority of the notification window
  ---
  --- Note that the default priority for Vim windows is 50.
  ---
  --- See also: options for |nvim_open_win()|
  ---
  ---@type number
  zindex = 45,

  --- Maximum width of the notification window
  ---
  --- `0` means no maximum width.
  ---
  ---@type integer
  max_width = 0,

  --- Maximum height of the notification window
  ---
  --- `0` means no maximum height.
  ---
  ---@type integer
  max_height = 0,

  --- Padding from right edge of window boundary
  ---
  ---@type integer
  x_padding = 1,

  --- Padding from bottom edge of window boundary
  ---
  ---@type integer
  y_padding = 0,

  --- How to align the notification window
  ---
  ---@type "top"|"bottom"|"avoid_cursor"
  align = "bottom",

  --- What the notification window position is relative to
  ---
  --- See also: options for |nvim_open_win()|
  ---
  ---@type "editor"|"win"
  relative = "editor",
}
---@options ]]

require("fidget.options").declare(M, "notification.window", M.options)

--- Local state maintained by this module.
---
--- If this framework were ever extended to support multiple concurrent windows,
--- this table's contents would need to be cloned.
local state = {
  --- ID of the buffer that notifications are rendered to.
  ---
  ---@type number|nil
  buffer_id = nil,

  --- ID of the window that the notification buffer is shown in.
  ---
  ---@type number|nil
  window_id = nil,

  --- ID of the namespace on which highlights are created.
  ---
  ---@type number|nil
  namespace_id = nil,

  --- Additional offset.
  ---
  --- Useful for adding additional padding to account for space
  --- taken up by other plugins' windows.
  ---
  ---@type number
  x_offset = 0,
}

--- Suppress errors that may occur while render windows.
---
--- The E523 error (Not allowed here) happens when 'secure' operations
--- (including buffer or window management) are invoked while textlock is held
--- or the Neovim UI is blocking. See #68.
---
--- Also ignore E11 (Invalid in command-line window), which is thrown when
--- Fidget tries to close the window while a command-line window is focused.
--- See #136.
---
--- This utility provides a workaround to simply supress the error.
--- All other errors will be re-thrown.
---
--- (Thanks @wookayin and @0xAdk!)
---
---@param callable fun()
---@return boolean suppressed_error
function M.guard(callable)
  local whitelist = {
    "E11: Invalid in command%-line window",
    "E523: Not allowed here",
    "E565: Not allowed to change",
  }

  local ok, err = pcall(callable)
  if ok then
    return true
  end

  if type(err) ~= "string" then
    -- Don't know how to deal with this kind of error object
    error(err)
  end

  for _, msg in ipairs(whitelist) do
    if string.find(err, msg) then
      return false
    end
  end

  error(err)
end

--- Get the current width and height of the editor window.
---
---@return number width
---@return number height
function M.get_editor_dimensions()
  local statusline_height = 0
  local laststatus = vim.opt.laststatus:get()
  if laststatus == 2 or laststatus == 3
      or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
  then
    statusline_height = 1
  end

  local height = vim.opt.lines:get() - (statusline_height + vim.opt.cmdheight:get())

  -- Does not account for &signcolumn or &foldcolumn, but there is no amazing way to get the
  -- actual "viewable" width of the editor
  --
  -- However, I cannot imagine that many people will render fidgets on the left side of their
  -- editor as it will more often overlay text
  local width = vim.opt.columns:get()

  return width, height
end

--- Compute the row, col, anchor for |nvim_open_win()| to align the window.
---
--- (Thanks @levouh!)
---
---@return number       row
---@return number       col
---@return ("NE"|"SE")  anchor
function M.get_window_position()
  local align_bottom, col, row, row_max
  local first_line = vim.fn.line("w0")
  local current_line = vim.api.nvim_win_get_cursor(0)[1]

  local function should_align_bottom(cursor_pos, rows)
    if M.options.align == "top" then
      return false
    elseif M.options.align == "bottom" then
      return true
    else
      return cursor_pos <= (rows / 2)
    end
  end

  if M.options.relative == "editor" then
    col, row_max = M.get_editor_dimensions()
    local window_pos = vim.api.nvim_win_get_position(0)
    local cursor_pos = window_pos[1] + (current_line - first_line)
    align_bottom = should_align_bottom(cursor_pos, row_max)

    if align_bottom then
      row = row_max
    else
      -- When the layout is anchored at the top, need to check &tabline height
      local stal = vim.opt.showtabline:get()
      local tabline_shown = stal == 2 or (stal == 1 and #vim.api.nvim_list_tabpages() > 1)
      row = tabline_shown and 1 or 0
    end
  else -- fidget relative to "window" (currently unreachable)
    local cursor_pos = current_line - first_line

    col = vim.api.nvim_win_get_width(0)
    row_max = vim.api.nvim_win_get_height(0)
    if vim.fn.exists("+winbar") > 0 and vim.opt.winbar:get() ~= "" then
      -- When winbar is set, effective win height is reduced by 1 (see :help winbar)
      row_max = row_max - 1
    end
    align_bottom = should_align_bottom(cursor_pos, row_max)

    row = align_bottom and row_max or 1
  end

  col = math.max(0, col - M.options.x_padding - state.x_offset)

  if align_bottom then
    row = math.max(0, row - M.options.y_padding)
  else
    row = math.min(row_max, row + M.options.y_padding)
  end

  return row, col, (align_bottom and "S" or "N") .. "E"
end

--- Set local options on a window.
---
--- Workaround for nvim bug where nvim_win_set_option "leaks" local options to
--- windows created afterwards.
---
--- (Thanks @sindrets!)
---
--- See also:
--- * https://github.com/b0o/incline.nvim/issues/4
--- * https://github.com/neovim/neovim/issues/18283
--- * https://github.com/neovim/neovim/issues/14670
---
---@param window_id number  window to on which options should be set
---@param opts      table   local options to set
function M.win_set_local_options(window_id, opts)
  vim.api.nvim_win_call(window_id, function()
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

--- Get the notification buffer ID; create it if it doesn't already exist.
---
---@return number buffer_id
function M.get_buffer()
  if state.buffer_id == nil or not vim.api.nvim_buf_is_valid(state.buffer_id) then
    -- Create an unlisted (1st param) scratch (2nd param) buffer
    state.buffer_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.buffer_id, "filetype", "fidget")
  end
  return state.buffer_id
end

--- Get the notification window ID; create it if it doesn't already exist.
---
--- Note that this will show the window as well, which is why it requires
--- a bunch of parameters that dictate how the window should be shown.
---
--- This also has the side effect of creating a notification buffer if it
--- doesn't already exist, associating it with the window.
---
---@param row     number
---@param col     number
---@param anchor  ("NW"|"NE"|"SW"|"SE")
---@param width   number
---@param height  number
---@return number window_id
function M.get_window(row, col, anchor, width, height)
  -- Clamp width and height to dimensions of editor and user specification.
  local editor_width, editor_height = M.get_editor_dimensions()

  width = math.min(width, editor_width - 4) -- guess width of signcolumn etc.
  if M.options.max_width > 0 then
    width = math.min(width, M.options.max_width)
  end

  height = math.min(height, editor_height)
  if M.options.max_height > 0 then
    height = math.min(height, M.options.max_height)
  end

  if state.window_id == nil or not vim.api.nvim_win_is_valid(state.window_id) then
    -- Create window to display notifications buffer, but don't enter (2nd param)
    state.window_id = vim.api.nvim_open_win(M.get_buffer(), false, {
      relative = M.options.relative,
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
      focusable = false,
      style = "minimal",
      border = M.options.border,
      zindex = M.options.zindex,
      noautocmd = true,
    })
  else
    -- Window is already created; reposition it in case anything has changed.
    vim.api.nvim_win_set_config(state.window_id, {
      relative = M.options.relative,
      row = row,
      col = col,
      anchor = anchor,
      width = width,
      height = height,
      -- NOTE: Should we care about the following options here??
      -- win = options.window.relative == "win" and api.nvim_get_current_win()
      --     or nil, -- only relevant if we support other relative values
      -- zindex = options.window.zindex,
    })
  end

  local winhighlight = ""

  if M.options.normal_hl ~= "" then
    -- Instead of NormalFloat
    winhighlight = winhighlight .. "NormalNC:" .. M.options.normal_hl
  end

  if M.options.border_hl ~= "" then
    winhighlight = winhighlight .. ",FloatBorder:" .. M.options.border_hl
  end

  M.win_set_local_options(state.window_id, {
    winblend = M.options.winblend, -- Transparent background
    winhighlight = winhighlight ~= "" and winhighlight or nil,
  })
  return state.window_id
end

--- Get the namespace ID used to apply highlights in the notification buffer.
---
--- Creates it if it doesn't already exist.
---
---@return number namespace_id
function M.get_namespace()
  if state.namespace_id == nil then
    state.namespace_id = vim.api.nvim_create_namespace("fidget-window")
  end
  return state.namespace_id
end

--- Show the notification window (and its buffer contents), editor-relative.
---
---@param width   number
---@param height  number
---@return number window_id
function M.show(width, height)
  local row, col, anchor = M.get_window_position()
  return M.get_window(row, col, anchor, width, height)
end

--- Replace the set of lines in the Fidget window, right-justify them, and apply
--- highlights.
---
--- To forego right-justification, pass nil for right_col.
---
---@param lines       string[]                  lines to place into buffer
---@param highlights  NotificationHighlight[]   list of highlights to apply
---@param right_col   number|nil                optional display width, to right-justify
function M.set_lines(lines, highlights, right_col)
  local buffer_id = M.get_buffer()
  local namespace_id = M.get_namespace()

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(buffer_id, namespace_id, 0, -1)

  if right_col then
    local offsets = {}

    -- Right justify each line by padding spaces
    for l, line in ipairs(lines) do
      local offset = right_col - vim.fn.strdisplaywidth(line)
      lines[l] = string.rep(" ", offset) .. lines[l]
      offsets[l] = offset
    end

    -- Replace entire buffer with new set of lines
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)

    for _, highlight in ipairs(highlights) do
      local offset = offsets[highlight.line + 1] -- highlight.line is 0-based, so needs +1
      vim.api.nvim_buf_add_highlight(
        buffer_id,
        namespace_id,
        highlight.hl_group,
        highlight.line,
        highlight.col_start + offset,
        highlight.col_end == -1 and -1 or highlight.col_end + offset)
    end
  else
    -- Replace entire buffer with new set of lines
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)

    for _, highlight in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(
        buffer_id,
        namespace_id,
        highlight.hl_group,
        highlight.line,
        highlight.col_start,
        highlight.col_end)
    end
  end
end

--- Close the Fidget window and associated buffers.
function M.close()
  if state.namespace_id ~= nil then
    if state.buffer_id ~= nil and vim.api.nvim_buf_is_valid(state.buffer_id) then
      vim.api.nvim_buf_clear_namespace(state.buffer_id, state.namespace_id, 0, -1)
    end
    state.namespace_id = nil
  end

  if state.window_id ~= nil then
    if vim.api.nvim_win_is_valid(state.window_id) then
      vim.api.nvim_win_close(state.window_id, true)
    end
    state.window_id = nil
  end

  if state.buffer_id ~= nil then
    if vim.api.nvim_buf_is_valid(state.buffer_id) then
      vim.api.nvim_buf_set_lines(state.buffer_id, 0, -1, false, {}) -- clear out text (is this necessary?)
      vim.api.nvim_buf_delete(state.buffer_id, { force = true })
    end
    state.buffer_id = nil
  end
end

--- Set x_offset, shifting the horizontal position of the notification window.
---
--- Unlike the x_padding option, this API is meant to be called
--- programmatically, and intended for dynamically adjusting padding to
--- compensate for other plugins' side panels (e.g., nvim-tree).
---
---@param offset number
function M.set_x_offset(offset)
  state.x_offset = offset
end

return M
