local M = {}

M.options = {
  ["nvim-tree"] = require("fidget.integration.nvim-tree"),
  ["xcodebuild-nvim"] = require("fidget.integration.xcodebuild-nvim"),
}

require("fidget.options").declare(M, "integration", M.options)

return M
