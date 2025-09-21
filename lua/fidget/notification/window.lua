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
local M      = {}
local logger = require("fidget.logger")

---@options notification.window [[
---@protected
--- Notifications window options
M.options    = {
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
  --- Non-integral numbers between `0` and `1` mean a fraction of the editor
  --- width, e.g., `0.5` for half of the editor.
  ---
  ---@type number
  max_width = 0.3,

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

  --- Width of each tab character in the notification window
  ---
  ---@type number
  tabstop = 8,

  --- Filetypes the notification window should avoid
  ---
  --- Example: ~
  --->lua
  ---   avoid = { "aerial", "NvimTree", "nerdtree", "neotest-summary" }
  ---<
  ---@type string[]
  avoid = {},
}
---@options ]]

require("fidget.options").declare(M, "notification.window", M.options)

--- The name of the highlight group that Fidget uses to prevent winblend from
--- "bleeding" the main editor window into the notification window.
M.no_blend_hl = "FidgetNoBlend"

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

---@param winnr integer
---@return boolean avoid whether to avoid this window
local function should_avoid(winnr)
  if vim.api.nvim_win_get_config(winnr).relative ~= "" then
    -- Always avoid floating windows
    return true
  end
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return ft == "fidget" or vim.tbl_contains(M.options.avoid, ft)
end

---@return integer height of the editor area, excludes statusline and tabline
local function get_editor_height()
  local statusline_height = 0
  local laststatus = vim.opt.laststatus:get()
  if laststatus == 2 or laststatus == 3
      or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
  then
    statusline_height = 1
  end

  return vim.opt.lines:get() - (statusline_height + vim.opt.cmdheight:get())
end

---@return integer width of the editor area, including signcolumn and foldcolumn
local function get_editor_width()
  return vim.opt.columns:get()
end

---@param winnr integer
---@return integer effective_height of the window, excluding winbar
local function get_effective_win_height(winnr)
  local height = vim.api.nvim_win_get_height(0)
  if vim.fn.exists("+winbar") > 0 and vim.opt.winbar:get() ~= "" then
    -- When winbar is set, effective win height is reduced by 1 (see :help winbar)
    return height - 1
  end
  return height
end

---@return integer tabline_height
local function get_tabline_height()
  local stal = vim.opt.showtabline:get()
  if stal == 2 or (stal == 1 and #vim.api.nvim_list_tabpages() > 1) then
    -- tabline is shown; height is 1
    return 1
  else
    return 0
  end
end

--- Compute the max width of the notification window.
---
---@return integer
function M.max_width()
  if M.options.max_width <= 0 then
    return math.huge
  end

  if M.options.max_width < 1 then
    local width = vim.opt.columns:get()
    return math.ceil(width * M.options.max_width)
  end

  return math.max(4, math.floor(M.options.max_width))
end

---@param cursor_row integer current line number of cursor
---@param max_rows integer total number of rows
---@return boolean whether to align bottom
local function should_align_bottom(cursor_row, max_rows)
  if M.options.align == "bottom" then
    return true
  elseif M.options.align == "top" then
    return false
  else -- M.options.align == "avoid_cursor"
    return cursor_row <= (max_rows / 2)
  end
end

--- Look for "best" window to align notification window with.
---
--- If none of the windows need to be avoided, then we should end up either
--- with the SE (align_bottom) or NE (not align_bottom) corner of the editor.
---
---@param row_max integer
---@param align_bottom boolean
---@return integer row
---@return integer col
local function search_for_editor_anchor(row_max, align_bottom)
  local row, col
  if align_bottom then
    row, col = -math.huge, -math.huge
  else
    row, col = math.huge, -math.huge
  end

  if #M.options.avoid == 0 then
    -- If M.options.avoid is empty, then we don't need to search through all
    -- windows, and can just directly (and more efficiently) set row/col to
    -- the editor's SE (align_bottom) or NE (not align_bottom) corner, later.
  else -- #M.options.avoid > 0
    -- Search for row/col of "best" window to align notification window with,
    -- while avoiding windows whose filetype is blacklisted by M.options.avoid.
    -- If none of the windows need to be avoided, we should still end up with
    -- the editor's SE (align_bottom) or NE (not align_bottom) corner.
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
      if not should_avoid(win) then
        local pos = vim.api.nvim_win_get_position(win)
        if align_bottom then
          -- Get SE corner of window
          local h, w = vim.api.nvim_win_get_height(win), vim.api.nvim_win_get_width(win)
          local r, c = pos[1] + h, pos[2] + w
          if r + c > row + col then
            row, col = r, c
          end
        else -- not align_bottom
          -- Get NE corner of window
          local w = vim.api.nvim_win_get_width(win)
          local r, c = pos[1], pos[2] + w
          if -r + c > -row + col then
            row, col = r, c
          end
        end
      end
    end
  end

  -- If row/col are never set (because there is nothing to avoid, or because we
  -- avoided everything), col will be negative. Set row/col to SE or NE corner
  -- of the editor so that we have _some_ valid position.
  if col < 0 then
    col = get_editor_width()
    row = align_bottom and row_max or get_tabline_height()
  end
  return row, col
end

--- Compute the row, col, anchor for |nvim_open_win()| to align the window.
---
---@return number           row
---@return number           col
---@return ("NE"|"SE")      anchor
---@return ("editor"|"win") relative
function M.get_window_position()
  local row_max, align_bottom, col, row, relative
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - vim.fn.line("w0")

  if M.options.relative == "win" and not should_avoid(0) then
    relative = "win"
    row_max = get_effective_win_height(0)
    align_bottom = should_align_bottom(cursor_row, row_max)
    row = align_bottom and row_max or 0
    col = vim.api.nvim_win_get_width(0)
  else -- M.options.relative == "editor", or we need to avoid current window
    relative = "editor"
    row_max = get_editor_height()
    local window_pos = vim.api.nvim_win_get_position(0)
    align_bottom = should_align_bottom(window_pos[1] + cursor_row, row_max)
    row, col = search_for_editor_anchor(row_max, align_bottom)
  end

  col = math.max(0, col - M.options.x_padding)
  row = align_bottom
      and math.max(0, row - M.options.y_padding)
      or math.min(row_max, row + M.options.y_padding)
  return row, col, (align_bottom and "S" or "N") .. "E", relative
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
    vim.api.nvim_set_option_value("filetype", "fidget", { buf = state.buffer_id })
    -- We set this to a known value to ensure we correctly account for the width
    -- of tab chars while calling strwidth() in notification.view.strwidth().
    vim.api.nvim_set_option_value("tabstop", M.options.tabstop, { buf = state.buffer_id })
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
--- Returns nil if Fidget window could not be created (e.g., because editor is
--- too small to show Fidget).
---
---@param row     number
---@param col     number
---@param anchor  ("NW"|"NE"|"SW"|"SE")
---@param relative ("editor"|"win")
---@param width   number
---@param height  number
---@return number|nil window_id
function M.get_window(row, col, anchor, relative, width, height)
  -- Clamp width and height to dimensions of editor and user specification.
  local editor_width, editor_height = get_editor_width(), get_editor_height()
  editor_width = math.max(0, editor_width - 4) -- HACK: guess width of signcolumn etc.

  if editor_width < 4 or editor_height < 4 then
    logger.info("Editor window is too small to display Fidget:", editor_width, "x", editor_height)
    M.close()
    return nil
  end

  -- Rendering with ext_marks causes lines to appear 1 character wider because
  -- the mark begins _after_ eol
  width = width + 1
  width = math.min(width, editor_width, M.max_width())

  height = math.min(height, editor_height)
  if M.options.max_height > 0 then
    height = math.min(height, M.options.max_height)
  end

  if state.window_id == nil or not vim.api.nvim_win_is_valid(state.window_id) then
    -- Create window to display notifications buffer, but don't enter (2nd param)
    state.window_id = vim.api.nvim_open_win(M.get_buffer(), false, {
      relative = relative,
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
    vim.api.nvim_win_set_hl_ns(state.window_id, M.get_namespace())
  else
    -- Window is already created; reposition it in case anything has changed.
    vim.api.nvim_win_set_config(state.window_id, {
      relative = relative,
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
    })
  end

  M.win_set_local_options(state.window_id, {
    winblend = M.options.winblend,
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

    local base_normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })

    local normal_hl = base_normal_hl
    if M.options.normal_hl ~= "" and M.options.normal_hl ~= "Normal" then
      -- Options say that we should use something else as Normal
      normal_hl = vim.api.nvim_get_hl(0, { name = M.options.normal_hl })

      -- A non-Normal highlight might lack a background, so we explicitly copy
      -- it over from the actual normal highlight group
      normal_hl.bg = normal_hl.bg or base_normal_hl.bg
    end

    -- For some reason, these are annotated as distinct types even though the
    -- documentation for nvim_get_hl() indicates they share the same schema.
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast normal_hl vim.api.keyset.highlight

    vim.api.nvim_set_hl(state.namespace_id, "Normal", normal_hl)
    vim.api.nvim_set_hl(state.namespace_id, "NormalNC", normal_hl)

    normal_hl.blend = 0
    vim.api.nvim_set_hl(state.namespace_id, M.no_blend_hl, normal_hl)

    local border_hl = vim.api.nvim_get_hl(0, {
      name = M.options.border_hl == "" and "FloatBorder" or M.options.border_hl,
    })

    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast border_hl vim.api.keyset.highlight

    -- Explicitly ignore FloatBorder background and use background from whatever
    -- was determined to be "normal", which is *probably* the right thing to do.
    border_hl.bg = normal_hl.bg

    vim.api.nvim_set_hl(state.namespace_id, "FloatBorder", border_hl)
  end
  return state.namespace_id
end

--- Show the notification window (and its buffer contents), editor-relative.
---
--- Returns nil if Fidget window could not be created (e.g., because editor is
--- too small to show Fidget).
---
---@param height  integer
---@param width   integer
---@return number|nil window_id
function M.show(height, width)
  local row, col, anchor, relative = M.get_window_position()
  return M.get_window(row, col, anchor, relative, width, height)
end

--- Replace the set of lines in the Fidget window, right-justify them, and apply
--- highlights.
---
---
---@param lines       NotificationLine[]  lines to place into buffer
---@param width       integer             width of longest line
function M.set_lines(lines, width)
  local buffer_id = M.get_buffer()
  local namespace_id = M.get_namespace()

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(buffer_id, namespace_id, 0, -1)

  -- Prepare empty lines for extmarks
  local empty_lines = vim.tbl_map(function() return "" end, lines)
  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, empty_lines)

  for iline, line in ipairs(lines) do
    if vim.fn.has("nvim-0.11.0") == 1 then
      vim.api.nvim_buf_set_extmark(buffer_id, namespace_id, iline - 1, 0, {
        virt_text = line,
        virt_text_pos = "eol_right_align",
      })
    else
      -- pre-0.11.0: eol_right_align was only introduced in 0.11.0;
      -- without it we need to compute and add the padding ourselves
      local len, padded = 0, { {} }
      for _, tok in ipairs(line) do
        len = len + vim.fn.strwidth(tok[1]) +
            vim.fn.count(tok[1], "\t") * math.max(0, M.options.tabstop - 1)
        table.insert(padded, tok)
      end
      local pad_width = math.max(0, width - len)
      if pad_width > 0 then
        padded[1] = { string.rep(" ", pad_width), {} }
      else
        padded = line
      end
      vim.api.nvim_buf_set_extmark(buffer_id, namespace_id, iline - 1, 0, {
        virt_text = padded,
        virt_text_pos = "eol",
      })
    end
  end
  M.show(vim.api.nvim_buf_line_count(buffer_id), width)
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
      vim.api.nvim_buf_delete(state.buffer_id, { force = true })
    end
    state.buffer_id = nil
  end
end

return M
