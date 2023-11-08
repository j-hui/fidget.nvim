local M = {}

local model = require("fidget.notification.model")
local window = require("fidget.notification.window")
local render = require("fidget.notification.render")

--- Default notification configuration. Useful for users to integrate for when
--- they are adding their own configs.
---
---@type NotificationConfig
M.default_config = {
  ttl = 1.5,
  icon = "❰❰❰",
  name_style = "Title",
  icon_style = "Constant",
  annote_style = "Comment",
}

require("fidget.options")(M, {
  --- Rate at which Fidget should render notifications view.
  poll_rate = 10,

  --- Configs, used to instantiate groups in the notification model.
  ---@type { [any]: NotificationConfig }
  configs = {
    default = M.default_config,
  },

  window = window,
}, function()
  -- Need to ensure that there is some sane default config.
  if not M.options.configs.default then
    M.options.configs.default = M.default_config
  end
end)

--- The "model" of notifications: a list of notification groups.
---@type NotificationGroup[]
local groups = {}

--- Arbitrary point in time that timestamps are computed relative to.
---@type number
local origin_time = vim.fn.reltime()

--- Timestamp for current poll frame. Only valid while actively polling.
---@type number?
local now_sync = nil

--- Send a notification to the Fidget notifications subsystem.
---
--- Can be used to override vim.notify(), e.g.,
---
---     vim.notify = require("fidget.notifications").notify
---
---@param msg     string?
---@param level   NotificationLevel?
---@param opts    NotificationOptions?
function M.notify(msg, level, opts)
  local now = vim.fn.reltimefloat(vim.fn.reltime(origin_time))
  model.update(now, M.options.configs, groups, msg, level, opts)
  M.start_polling()
end

function M.poll()
  local now = now_sync or vim.fn.reltimefloat(vim.fn.reltime(origin_time))
  groups = model.tick(now, groups)
  local view = render.render_view(now, groups)
  if #view.lines > 0 then
    -- TODO: if not modified, don't re-render
    -- TODO: check for textlock etc, other things that should cause us to skip this frame.
    window.set_lines(view.lines, view.highlights, view.width)
    window.show(view.width, #view.lines)
  else
    window.close()
  end

  return true
end

--- Counting semaphore used to guard against starting multiple pollers.
local poll_count = 0

--- Whether Fidget is currently polling for progress messages.
function M.is_polling()
  return poll_count > 0
end

--- Start periodically polling for progress messages, until we stop receiving them.
function M.start_polling()
  if M.is_polling() then return end
  poll_count = poll_count + 1
  local done, timer, delay = false, vim.loop.new_timer(), math.ceil(1000 / M.options.poll_rate)
  timer:start(15, delay, vim.schedule_wrap(function() -- Note: hard-coded 15ms attack
    if done then return end
    now_sync = vim.fn.reltimefloat(vim.fn.reltime(origin_time))
    if not M.poll() then
      timer:stop()
      timer:close()
      done = true
      poll_count = poll_count - 1
    end
    now_sync = nil
  end)
  )
end

return M
