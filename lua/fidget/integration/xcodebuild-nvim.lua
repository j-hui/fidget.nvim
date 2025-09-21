local M = {}

---@options integration.xcodebuild-nvim [[
--- xcodebuild.nvim integration
M.options = {
  --- Integrate with wojciech-kulik/xcodebuild.nvim (if installed)
  ---
  --- DEPRECATED; use notification.window.avoid = { "NvimTree" }
  ---
  ---@type boolean
  enable = true,
}
---@options ]]

require("fidget.options").declare(M, "integration.xcodebuild-nvim", M.options, function()
  if not M.options.enable then
    return
  end

  local ok, _ = pcall(require, "xcodebuild")
  if not ok then
    return
  end

  -- TODO: deprecation notice

  local win = require("fidget.notification.window")
  if not vim.tbl_contains(win.options.avoid, "TestExplorer") then
    table.insert(win.options.avoid, "TestExplorer")
  end
end)

return M
