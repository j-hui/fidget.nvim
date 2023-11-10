--- Fidget's top-level module.
local M        = {}
M.progress     = require("fidget.progress")
M.notification = require("fidget.notification")
M.spinner      = require("fidget.spinner")
M.logger       = require("fidget.logger")

require("fidget.options")(M, {
  progress = M.progress,
  notification = M.notification,
  logger = M.logger,
}, function()
  M.logger.info("fidget.nvim setup complete.")
end)

M.notify = M.notification.notify

return M
