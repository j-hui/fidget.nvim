local M = {}
local DEPRECATED = require("fidget.options").deprecated

---@options integration.nvim-tree [[
--- nvim-tree integration
M.options = {
  --- Integrate with nvim-tree/nvim-tree.lua (if installed)
  ---
  ---@type fidget.DeprecatedOption<boolean>
  enable = DEPRECATED(true, [[Use 'notification.window.avoid = { "NvimTree" }' instead]])
}
---@options ]]

require("fidget.options").declare(M, "integration.nvim-tree", M.options)

function M.plugin_present()
  local ok, _ = pcall(require, "nvim-tree.api")
  return ok
end

function M.integration_needed()
  return M.options.enable and M.plugin_present()
end

function M.explicitly_configured()
  return not (type(M.options.enable) == "table" and M.options.enable.deprecated_option)
end

M.filetype = "NvimTree"

return M
