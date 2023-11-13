--- Fidget's notification subsystem.
local M          = {}
M.model          = require("fidget.notification.model")
M.window         = require("fidget.notification.window")
M.view           = require("fidget.notification.view")
local poll       = require("fidget.poll")
local logger     = require("fidget.logger")

--- Used to determine the identity of notification items and groups.
---@alias NotificationKey any

--- Second (level) paramter passed to fidget.notification.notify().
---
--- `string` indicates highlight group name; otherwise, `number` indicates
--- the `:h vim.log.levels` value (that will resolve to a highlight group as
--- determined by the `:h NotificationConfig`).
---@alias NotificationLevel number | string

--- Third (opts) parameter passed to fidget.notification.notify().
---@class NotificationOptions
---@field key           NotificationKey?  Replace existing notification item of the same key
---@field group         any?      Group that this notification item belongs to
---@field annote        string?   Optional single-line title that accompanies the message
---@field hidden        boolean?  Whether this item should be shown
---@field ttl           number?   How long after a notification item should exist; pass 0 to use default value
---@field update_only   boolean?  If true, don't create new notification items
---@field data          any?      Arbitrary data attached to notification item

--- Something that can be displayed in a NotificationGroup.
---
--- If a callable `function`, it is invoked every render cycle with the items
--- list; useful for rendering animations and other dynamic content.
---@alias NotificationDisplay string | fun(now: number, items: NotificationItem[]): string

--- Used to configure the behavior of notification groups.
---
--- If both name and icon are nil, then no group header is rendered.
---
---@class NotificationConfig
---@field name              NotificationDisplay?  name of the group
---@field icon              NotificationDisplay?  icon of the group
---@field icon_on_left      boolean?  if true, icon is rendered on the left instead of right
---@field annote_separator  string?   separator between message from annote; defaults to " "
---@field ttl               number?   how long a notification item should exist; defaults to 3
---@field group_style       string?   style used to highlight group name; defaults to "Title"
---@field icon_style        string?   style used to highlight icon; if nil, use group_style
---@field annote_style      string?   default style used to highlight item annotes; defaults to "Question"
---@field debug_style       string?   style used to highlight debug item annotes
---@field info_style        string?   style used to highlight info item annotes
---@field warn_style        string?   style used to highlight warn item annotes
---@field error_style       string?   style used to highlight error item annotes
---@field debug_annote      string?   default annotation for debug items
---@field info_annote       string?   default annotation for info items
---@field warn_annote       string?   default annotation for warn items
---@field error_annote      string?   default annotation for error items
---@field priority          number?   order in which group should be displayed; defaults to 50

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
  debug_style = "Comment",
  info_style = "Question",
  warn_style = "WarningMsg",
  error_style = "ErrorMsg",
  debug_annote = "DEBUG",
  info_annote = "INFO",
  warn_annote = "WARN",
  error_annote = "ERROR",
}

--- Options related to notification subsystem
require("fidget.options").declare(M, "notification", {
  --- How frequently to poll and render notifications
  ---
  --- Measured in Hertz (frames per second).
  ---
  ---@type number
  poll_rate = 10,

  --- Automatically override vim.notify() with Fidget
  ---
  --- Equivalent to the following:
  ---
  --- ```lua
  --- fidget.setup({ --[[ options ]] })
  --- vim.notify = fidget.notify
  --- ```
  ---
  ---@type boolean
  override_vim_notify = false,

  --- How to configure notification groups when instantiated
  ---
  --- A configuration with the key `"default"` should always be specified, and
  --- is used as the fallback for notifications lacking a group key.
  ---
  ---@type { [NotificationKey]: NotificationConfig }
  configs = { default = M.default_config },

  view = M.view,
  window = M.window,
}, function()
  -- Need to ensure that there is some sane default config.
  if not M.options.configs.default then
    logger.warn("no default notification config specified; using default")
    M.options.configs.default = M.default_config
  end
end)

--- The "model" of notifications: a list of notification groups.
---@type NotificationGroup[]
local groups = {}

--- Whether the notification window is suppressed.
local view_suppressed = false

--- Send a notification to the Fidget notifications subsystem.
---
--- Can be used to override `vim.notify()`, e.g.,
---
--- ```lua
--- vim.notify = require("fidget.notifications").notify
--- ```
---
---@param msg     string?
---@param level   NotificationLevel?
---@param opts    NotificationOptions?
function M.notify(msg, level, opts)
  local now = poll.get_time()
  local n_groups = #groups
  M.model.update(now, M.options.configs, groups, msg, level, opts)
  if n_groups ~= #groups then
    groups = vim.fn.sort(groups, function(a, b) return (a.config.priority or 50) - (b.config.priority or 50) end)
  end
  M.poller:start_polling(M.options.poll_rate)
end

--- Close the notification window.
---
---@return boolean closed_successfully
function M.close()
  return M.window.guard(function()
    M.window.close()
  end)
end

--- The poller for the notification subsystem.
M.poller = poll.Poller {
  name = "notification",
  poll = function(self)
    groups = M.model.tick(self:now(), groups)

    -- TODO: if not modified, don't re-render
    local v = M.view.render(self:now(), groups)

    if #v.lines > 0 then
      if view_suppressed then
        return true
      end

      M.window.guard(function()
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
}

--- Dynamically add, overwrite, or delete a notification configuration.
---
---@param key     NotificationKey
---@param config  NotificationConfig?
---@param overwrite boolean
function M.set_config(key, config, overwrite)
  if overwrite or not M.options.configs[key] then
    M.options.configs[key] = config
  end
end

--- Suppress whether the notification window is shown.
---
--- Pass `true` as argument to turn on suppression, or `false` to turn it off.
---
--- If no argument is given, suppression state is toggled.
---@param suppress boolean? Whether to suppress or toggle suppression
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
