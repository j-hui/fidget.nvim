local M = {}

local logger = require("fidget.logger")
local notification = require("fidget.notification")
local progress = require("fidget.progress")

require("fidget.options")(M, {
  logger = logger,
  notification = notification,
  progress = progress,
}, function()
  logger.info("finished setting up fidget.nvim")
end)

return M
