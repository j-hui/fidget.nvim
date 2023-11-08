local M = {}

local notification = require("fidget.notification")
local progress = require("fidget.progress")

require("fidget.options")(M, {
  progress = progress,
  notification = notification,
})

return M
