--- Fidget's top-level module.
---
--- For now, this doesn't do anything other than expose a setup() function.
local M            = {}
local logger       = require("fidget.logger")
local notification = require("fidget.notification")
local progress     = require("fidget.progress")

require("fidget.options")(M, {
  logger = logger,
  notification = notification,
  progress = progress,
}, function()
  logger.info("finished setting up fidget.nvim")
end)

return M
