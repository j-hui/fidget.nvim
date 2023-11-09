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
  M.logger.info("fidget.nvim setup complete.")
end)

M.notify = M.notification.notify

M.suppress_progress = M.progress.suppress

M.suppress_notifications = M.notification.suppress

return M
