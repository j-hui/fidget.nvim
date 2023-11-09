--- Fidget's top-level module.
local M        = {}
M.logger       = require("fidget.logger")
M.notification = require("fidget.notification")
M.progress     = require("fidget.progress")

require("fidget.options")(M, {
  logger = M.logger,
  notification = M.notification,
  progress = M.progress,
}, function()
  M.logger.info("finished setting up fidget.nvim")
end)

M.notify = M.notification.notify

return M
