local M = {}

M.options = {
  ["nvim-tree"] = require("fidget.integration.nvim-tree")
}

require("fidget.options").declare(M, "integration", M.options)

return M
