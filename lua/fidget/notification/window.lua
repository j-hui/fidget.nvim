--- This module encapsulates state and helper functions associated with managing
--- nvim buffers and windows that are used to display notifications.
---
--- Not part of the public API (but do what you want with it).
---
--- If this framework were to be expanded to support multiple concurrent
--- instances of the model, this module's contents would need to be cloned.
local M = {}

require("fidget.options")(M, {
  winblend = 100,
  normal_hl = "Normal",
  border = "none",
  zindex = 45,
  max_width = 0,
  max_height = 0,
})

--- Get the current width and height of the editor window.
---
---@return number width
---@return number height
function M.get_editor_dimensions()
  local statusline_height = 0
  local laststatus = vim.opt.laststatus:get()
  if
      laststatus == 2
      or laststatus == 3
      or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins() > 1)
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

--- Compute the row, col, anchor for nvim_open_win() to align the window.
---
--- (Thanks @levouh!)
---
---@param  relative     ("editor" | "win")  what the window is relative to
---@param  align_bottom boolean             whether to align to the bottom
---@param  align_right  boolean             wheter to align to the right
---@return number                 row
---@return number                 col
---@return ("NW"|"NE"|"SW"|"SE")  anchor
function M.get_window_position(relative, align_bottom, align_right)
  local width, height, baseheight
  if relative == "editor" then
    width, height = M.get_editor_dimensions()

    -- Applies when the layout is anchored at the top, need to check &tabline height
    baseheight = 0
    if relative == "editor" then
      local showtabline = vim.opt.showtabline:get()
      if
          showtabline == 2
          or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
      then
        baseheight = 1
      end
    end
  else -- fidget relative to window.
    height = vim.api.nvim_win_get_height(0)
    width = vim.api.nvim_win_get_width(0)

    if vim.fn.exists("+winbar") > 0 and vim.opt.winbar:get() ~= "" then
      -- When winbar is enabled, the effective window height should be
      -- decreased by 1. (see :help winbar)
      height = height - 1
    end

    baseheight = 1
  end

  return
      align_bottom and height or baseheight,
      align_right and width or 1,
      (align_bottom and "S" or "N") .. (align_right and "E" or "W")
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

--- ID of the buffer that notifications are rendered to.
---@type number?
M.buffer_id = nil

--- Get the buffer ID of the notification buffer; create it if it doesn't
--- already exist.
---@return unknown
function M.get_buffer()
  if M.buffer_id == nil or not vim.api.nvim_buf_is_valid(M.buffer_id) then
    -- Create an unlisted (1st param) scratch (2nd param) buffer
    M.buffer_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.buffer_id, "filetype", "fidget")
  end
  return M.buffer_id
end

--- ID of the window that the notification buffer is shown in.
---@type number?
M.window_id = nil

function M.get_window(row, col, anchor, width, height)
  -- Clamp width and height to dimensions of editor and user specification.
  local editor_width, editor_height = M.get_editor_dimensions()

  width = math.min(width, editor_width - 4) -- guess width of signcolumn etc.
  if M.options.max_width > 0 then
    width = math.min(width, M.optins.max_width)
  end

  height = math.min(height, editor_height)
  if M.options.max_height > 0 then
    height = math.min(height, M.optins.max_height)
  end

  if M.window_id == nil or not vim.api.nvim_win_is_valid(M.window_id) then
    -- Create window to display notifications buffer, but don't enter (2nd param)
    M.window_id = vim.api.nvim_open_win(M.get_buffer(), false, {
      relative = "editor",
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
    vim.api.nvim_win_set_config(M.window_id, {
      relative = "editor",
      row = row,
      col = col,
      anchor = anchor,
      width = width,
      height = height,
      -- TODO: Should we care about the following options here??
      -- win = options.window.relative == "win" and api.nvim_get_current_win()
      --     or nil, -- only relevant if we support other relative values
      -- zindex = options.window.zindex,
    })
  end

  M.win_set_local_options(M.window_id, {
    winblend = M.options.winblend,                   -- Transparent background
    winhighlight = "Normal:" .. M.options.normal_hl, -- Instead of NormalFloat
  })
  return M.window_id
end

function M.show(width, height)
  local row, col, anchor = M.get_window_position("editor", true, true)
  M.get_window(row, col, anchor, width, height)
end

function M.set_lines(lines, highlights, right_justify_col)
  local buffer_id = M.get_buffer()
  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)

  if right_justify_col then
    -- TODO: add highlights
    vim.api.nvim_buf_call(buffer_id, function()
      vim.api.nvim_cmd({ cmd = "right", args = { tostring(right_justify_col) }, range = { 1, #lines } }, {})
    end)
  end
end

function M.close()
  if M.window_id ~= nil then
    if vim.api.nvim_win_is_valid(M.window_id) then
      vim.api.nvim_win_close(M.window_id, true)
    end
    M.window_id = nil
  end

  if M.buffer_id ~= nil then
    if vim.api.nvim_buf_is_valid(M.buffer_id) then
      vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, {}) -- clear out text (is this necessary?)
      vim.api.nvim_buf_delete(M.buffer_id, { force = true })
    end
    M.buffer_id = nil
  end
end

return M
