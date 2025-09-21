local M = {}

---@options integration.nvim-tree [[
--- nvim-tree integration
M.options = {
  --- Integrate with nvim-tree/nvim-tree.lua (if installed)
  ---
  --- DEPRECATED; use notification.window.avoid = { "NvimTree" }
  ---
  ---@type boolean
  enable = true,
}
---@options ]]

require("fidget.options").declare(M, "integration.nvim-tree", M.options, function()
  if not M.options.enable then
    return
  end

  local ok, _ = pcall(function() return require("nvim-tree.api") end)
  if not ok then
    return
  end

  -- TODO: deprecation notice

  local win = require("fidget.notification.window")
  if not vim.tbl_contains(win.options.avoid, "NvimTree") then
    table.insert(win.options.avoid, "NvimTree")
  end
end)

return M
