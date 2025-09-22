---@diagnostic disable: unused-local

---@brief [[
---*fidget-api.txt*     For Neovim version 0.8+            Last change: see Git log
---@brief ]]
---
---@toc fidget.api.toc
---
---@brief [[
---                                                                    *fidget.api*
--- This file contains generated documentation for Fidget's Lua API, though of
--- course you will also find plenty more detail documented in the source code.
---
--- For help setting up this plugin, see |fidget.txt| and |fidget-option.txt|.
---@brief ]]

---Fidget's top-level module.
local fidget        = {}
fidget.progress     = require("fidget.progress")
fidget.notification = require("fidget.notification")
fidget.spinner      = require("fidget.spinner")
fidget.logger       = require("fidget.logger")
local commands      = require("fidget.commands")

--- Set up Fidget plugin.
---
---@param opts table Plugin options. See |fidget-options| or |fidget-option.txt|.
function fidget.setup(opts) end

---@options [[
---@protected
--- Options for |fidget.setup|
fidget.options = {
  progress = fidget.progress,
  notification = fidget.notification,
  logger = fidget.logger,
  integration = require("fidget.integration")
}
---@options ]]

require("fidget.options").declare(fidget, "", fidget.options, function()
  commands.setup()
  if fidget.options.notification.override_vim_notify then
    fidget.logger.info("overriding vim.notify() with fidget.notify()")
    vim.notify = fidget.notify
  end
  fidget.logger.info("fidget.nvim setup() complete.")
end)

--- Alias for |fidget.notification.notify|.
---@param msg   string|nil  Content of the notification to show to the user.
---@param level Level|nil   How to format the notification.
---@param opts  Options|nil Optional parameters (see |fidget.notification.Options|).
function fidget.notify(msg, level, opts)
  fidget.notification.notify(msg, level, opts)
end

fidget.notify = fidget.notification.notify

return fidget
