--- Fidget's notification subsystem.
local M          = {}
M.model          = require("fidget.notification.model")
M.window         = require("fidget.notification.window")
M.view           = require("fidget.notification.view")
local logger     = require("fidget.logger")

--- Default notification configuration.
---
--- Exposed publicly because it might be useful for users to integrate for when
--- they are adding their own configs.
---
---@type NotificationConfig
M.default_config = {
  name = "Notifications",
  icon = "❰❰",
  ttl = 5,
  group_style = "Title",
  icon_style = "Special",
  annote_style = "Question",
}

require("fidget.options")(M, {
  --- Rate at which Fidget should render notifications view.
  poll_rate = 10,

  --- Configs, used to instantiate groups in the notification model.
  ---@type { [any]: NotificationConfig }
  configs = { default = M.default_config },

  view = M.view,
  window = M.window,
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

--- Whether the notification window is suppressed.
local view_suppressed = false

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
  local n_groups = #groups
  M.model.update(now, M.options.configs, groups, msg, level, opts)
  if n_groups ~= #groups then
    groups = vim.fn.sort(groups, function(a, b) return (a.config.priority or 50) - (b.config.priority or 50) end)
  end
  M.start_polling()
end

--- Suppress errors that may occur while render windows.
---
--- The E523 error (Not allowed here) happens when 'secure' operations
--- (including buffer or window management) are invoked while textlock is held
--- or the Neovim UI is blocking. See #68.
---
--- Also ignore E11 (Invalid in command-line window), which is thrown when
--- Fidget tries to close the window while a command-line window is focused.
--- See #136.
---
--- This utility provides a workaround to simply supress the error.
--- All other errors will be re-thrown.
---
--- (Thanks @wookayin and @0xAdk!)
---
---@param callable fun()
---@return boolean suppressed_error
local function window_guard(callable)
  local function error_allowed(err)
    if type(err) ~= "string" then return false end
    if string.find(err, "E11: Invalid in command%-line window") then return true end
    if string.find(err, "E523: Not allowed here") then return true end
    return false
  end
  local ok, err = pcall(callable)
  if ok then return true end
  if error_allowed(err) then return false end
  error(err)
end

--- Close the notification window.
---
---@return boolean closed_successfully
function M.close()
  return window_guard(function()
    M.window.close()
  end)
end

function M.poll()
  local now = now_sync or vim.fn.reltimefloat(vim.fn.reltime(origin_time))

  -- TODO: if not modified, don't re-render
  local v = M.view.render(now, groups)

  if #v.lines > 0 then
    if view_suppressed then
      return true
    end

    window_guard(function()
      M.window.set_lines(v.lines, v.highlights, v.width)
      M.window.show(v.width, #v.lines)
    end)
    return true
  else
    if view_suppressed then
      return false
    end

    -- If we could not close the window, keep polling, i.e., keep trying to close the window.
    return not M.close()
  end
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
  logger.info("starting notification poller")
  poll_count = poll_count + 1
  local done, timer, delay = false, vim.loop.new_timer(), math.ceil(1000 / M.options.poll_rate)
  timer:start(15, delay, vim.schedule_wrap(function() -- Note: hard-coded 15ms attack
    if done then return end
    now_sync = vim.fn.reltimefloat(vim.fn.reltime(origin_time))
    if not M.poll() then
      logger.info("stopping notification poller")
      timer:stop()
      timer:close()
      done = true
      poll_count = poll_count - 1
    end
    now_sync = nil
  end)
  )
end

--- Dynamically add, overwrite, or delete a notification configuration.
---
---@param key     any
---@param config  NotificationConfig?
---@param overwrite boolean
function M.set_config(key, config, overwrite)
  if overwrite or not M.options.configs[key] then
    M.options.configs[key] = config
  end
end

--- Suppress whether the notification window is shown.
---
--- Pass false as argument to turn off suppression.
---
--- If no argument is given, suppression state is toggled.
---@param suppress boolean?
function M.suppress(suppress)
  if suppress == nil then
    view_suppressed = not view_suppressed
  else
    view_suppressed = suppress
  end

  if view_suppressed then
    M.close()
  end
end

return M
