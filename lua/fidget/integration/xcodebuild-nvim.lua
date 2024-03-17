local M = {}

---@options integration.xcodebuild-nvim [[
--- xcodebuild.nvim integration
M.options = {
  --- Integrate with wojciech-kulik/xcodebuild.nvim (if installed)
  ---
  --- Dynamically offset Fidget's notifications window when the Test Explorer window
  --- is open on the right side + the Fidget window is "editor"-relative.
  ---
  ---@type boolean
  enable = true,
}
---@options ]]

require("fidget.options").declare(M, "integration.xcodebuild-nvim", M.options, function()
  local au_group = vim.api.nvim_create_augroup("FidgetXcodebuildNvim", { clear = true })

  if not M.options.enable then
    return
  end

  local ok, _ = pcall(require, "xcodebuild")
  if not ok then
    return
  end

  local win = require("fidget.notification.window")
  local test_explorer_winid = nil

  local function is_any_window_below(row, height)
    local all_windows = vim.api.nvim_list_wins()
    local bottom_row = row + height

    for _, winnr in ipairs(all_windows) do
      local win_row  = vim.api.nvim_win_get_position(winnr)[1]

      if win_row > bottom_row then
        return true
      end
    end

    return false
  end

  local function resize(winid)
    test_explorer_winid = winid

    if win.options.relative == "editor" then
      local row, col = unpack(vim.api.nvim_win_get_position(winid))

      if col > 1 then
        local height = vim.api.nvim_win_get_height(winid)

        if is_any_window_below(row, height) then
          win.set_x_offset(0)
        else
          local width = vim.api.nvim_win_get_width(winid)
          win.set_x_offset(width + 1)
        end
      end
    end
  end

  local function reset()
    test_explorer_winid = nil
    win.set_x_offset(0)
  end

  local bufnr = require("xcodebuild.tests.explorer").bufnr
  if bufnr then
    local winnr = vim.fn.win_findbuf(bufnr)
    if winnr[1] then
      resize(winnr[1])
    end
  end

  vim.api.nvim_create_autocmd("User", {
    group = au_group,
    pattern = "XcodebuildTestExplorerToggled",
    callback = function(event)
      local data = event.data

      if data.visible and data.winnr then
        resize(data.winnr)
      else
        reset()
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinResized", {
    group = au_group,
    pattern = "*",
    callback = function()
      if not test_explorer_winid then
        return
      end

      if vim.api.nvim_win_is_valid(test_explorer_winid) then
        resize(test_explorer_winid)
      else
        reset()
      end
    end,
  })
end
)

return M
