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

  local function resize(winid)
    test_explorer_winid = winid

    if win.options.relative == "editor" then
      local col = vim.api.nvim_win_get_position(winid)[2]

      if col > 1 then
        local width = vim.api.nvim_win_get_width(winid)
        win.set_x_offset(width + 1)
      end
    end
  end

  local function reset()
    test_explorer_winid = nil
    win.set_x_offset(0)
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
