--- Fidget's top-level module.
local M        = {}
M.progress     = require("fidget.progress")
M.notification = require("fidget.notification")
M.spinner      = require("fidget.spinner")
M.logger       = require("fidget.logger")

require("fidget.options").declare(M, "", {
  progress = M.progress,
  notification = M.notification,
  logger = M.logger,
}, function(warn_log)
  if M.options.notification.override_vim_notify then
    M.logger.info("overriding vim.notify() with fidget.notify()")
    vim.notify = M.notify
  end

  M.logger.info("fidget.nvim setup() complete.")
  if #warn_log > 0 then
    M.logger.warn("Encountered unknown options during setup():")
    for _, w in ipairs(warn_log) do
      M.logger.warn("-", w)
    end
  end
end)

M.notify = M.notification.notify

return M
