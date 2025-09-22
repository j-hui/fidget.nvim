local M = {}
local DEPRECATED = require("fidget.options").deprecated

---@options integration.xcodebuild-nvim [[
--- xcodebuild.nvim integration
M.options = {
  --- Integrate with wojciech-kulik/xcodebuild.nvim (if installed)
  ---
  ---@type fidget.DeprecatedOption<boolean>
  enable = DEPRECATED(true, [[Use 'notification.window.avoid = { "TestExplorer" }' instead]])
}
---@options ]]

require("fidget.options").declare(M, "integration.xcodebuild-nvim", M.options)

function M.plugin_present()
  local ok, _ = pcall(require, "xcodebuild")
  return ok
end

function M.integration_needed()
  return M.options.enable and M.plugin_present()
end

function M.explicitly_configured()
  return not (type(M.options.enable) == "table" and M.options.enable.deprecated_option)
end

M.filetype = "TestExplorer"

return M
