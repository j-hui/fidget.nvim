---@mod fidget.notification Notification subsystem
local notification          = {}
notification.model          = require("fidget.notification.model")
notification.window         = require("fidget.notification.window")
notification.view           = require("fidget.notification.view")
local poll                  = require("fidget.poll")
local logger                = require("fidget.logger")

--- Used to determine the identity of notification items and groups.
---@alias Key any

--- Second (level) paramter passed to |fidget.notification.notify|.
---
--- `string` indicates highlight group name; otherwise, `number` indicates
--- the |vim.log.levels| value (that will resolve to a highlight group as
--- determined by the |fidget.notification.Config|).
---@alias Level number|string

--- Third (opts) parameter passed to |fidget.notification.notify|.
---@class Options
---@field key           Key|nil       Replace existing notification item of the same key
---@field group         any|nil       Group that this notification item belongs to
---@field annote        string|nil    Optional single-line title that accompanies the message
---@field hidden        boolean|nil   Whether this item should be shown
---@field ttl           number|nil    How long after a notification item should exist; pass 0 to use default value
---@field update_only   boolean|nil   If true, don't create new notification items
---@field data          any|nil       Arbitrary data attached to notification item

--- Something that can be displayed in a |fidget.notification.Group|.
---
--- If a callable `function`, it is invoked every render cycle with the items
--- list; useful for rendering animations and other dynamic content.
---@alias Display string|fun(now: number, items: Item[]): string

--- Used to configure the behavior of notification groups.
---
--- If both name and icon are nil, then no group header is rendered.
---
--- Note that the actual `|fidget.notification.default_config|` defines a few
--- more defaults than what is documented here, which pertain to the fallback
--- used if the corresponding field in the `default` config table is `nil`.
---
---@class Config
---@field name              Display|nil   Name of the group
---@field icon              Display|nil   Icon of the group
---@field icon_on_left      boolean|nil   If `true`, icon is rendered on the left instead of right
---@field annote_separator  string|nil    Separator between message from annote; defaults to `" "`
---@field ttl               number|nil    How long a notification item should exist; defaults to `5`
---@field render_limit      number|nil    How many notification items to show at once
---@field group_style       string|nil    Style used to highlight group name; defaults to `"Title"`
---@field icon_style        string|nil    Style used to highlight icon; if nil, use `group_style`
---@field annote_style      string|nil    Default style used to highlight item annotes; defaults to `"Question"`
---@field debug_style       string|nil    Style used to highlight debug item annotes
---@field info_style        string|nil    Style used to highlight info item annotes
---@field warn_style        string|nil    Style used to highlight warn item annotes
---@field error_style       string|nil    Style used to highlight error item annotes
---@field debug_annote      string|nil    Default annotation for debug items
---@field info_annote       string|nil    Default annotation for info items
---@field warn_annote       string|nil    Default annotation for warn items
---@field error_annote      string|nil    Default annotation for error items
---@field priority          number|nil    Order in which group should be displayed; defaults to `50`

--- Default notification configuration.
---
--- Exposed publicly because it might be useful for users to integrate for when
--- they are adding their own configs.
---
--- To see the default values, run:
---
--->vim
--- :lua print(vim.inspect(require("fidget.notification").default_config))
---<
---
---@type Config
notification.default_config = {
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

---@options notification [[
---@protected
--- Notification options
notification.options        = {
  --- How frequently to update and render notifications
  ---
  --- Measured in Hertz (frames per second).
  ---
  ---@type number
  poll_rate = 10,

  --- Minimum notifications level
  ---
  --- Note that this filter only applies to notifications with an explicit
  --- numeric level (i.e., `vim.log.levels`).
  ---
  --- Set to `vim.log.levels.OFF` to filter out all notifications with an
  --- numeric level, or `vim.log.levels.TRACE` to turn off filtering.
  ---
  ---@type 0|1|2|3|4|5
  filter = vim.log.levels.INFO,

  --- Automatically override vim.notify() with Fidget
  ---
  --- Equivalent to the following:
  --->lua
  ---     fidget.setup({ --[[ options ]] })
  ---     vim.notify = fidget.notify
  ---<
  ---
  ---@type boolean
  override_vim_notify = false,

  --- How to configure notification groups when instantiated
  ---
  --- A configuration with the key `"default"` should always be specified, and
  --- is used as the fallback for notifications lacking a group key.
  ---
  --- To see the default config, run:
  --->vim
  ---     :lua print(vim.inspect(require("fidget.notification").default_config))
  ---<
  ---
  ---@type table<Key, Config>
  configs = { default = notification.default_config },

  view = notification.view,
  window = notification.window,
}
---@options ]]

require("fidget.options").declare(notification, "notification", notification.options, function()
  -- Need to ensure that there is some sane default config.
  if not notification.options.configs.default then
    logger.warn("no default notification config specified; using default")
    notification.options.configs.default = notification.default_config
  end
end)

--- The "model" of notifications: a list of notification groups.
---@type Group[]
local groups = {}

--- Whether the notification window is suppressed.
local view_suppressed = false

--- Send a notification to the Fidget notifications subsystem.
---
--- Can be used to override `vim.notify()`, e.g.,
---
--->lua
--- vim.notify = require("fidget.notifications").notify
---<
---
---@param msg     string|nil  Content of the notification to show to the user.
---@param level   Level|nil   How to format the notification.
---@param opts    Options|nil Optional parameters (see |fidget.notification.Options|).
function notification.notify(msg, level, opts)
  if msg ~= nil and type(msg) ~= "string" then
    error("message: expected string, got " .. type(msg))
  end

  if level ~= nil and type(level) ~= "number" and type(level) ~= "string" then
    error("level: expected number | string, got " .. type(level))
  end

  if opts ~= nil and type(opts) ~= "table" then
    error("opts: expected table, got " .. type(opts))
  end

  if type(level) == "number" and level < notification.options.filter then
    logger.info(string.format("Filtered out notification (%s): %s", logger.fmt_level(level), msg))
    return
  end

  local now = poll.get_time()
  local n_groups = #groups
  notification.model.update(now, notification.options.configs, groups, msg, level, opts)
  if n_groups ~= #groups then
    groups = vim.fn.sort(groups, function(a, b) return (a.config.priority or 50) - (b.config.priority or 50) end)
  end
  notification.poller:start_polling(notification.options.poll_rate)
end

--- Close the notification window.
---
--- Note that it the window will pop open again as soon as there is any reason
--- to (e.g., if another notification or LSP progress message is received).
---
--- To temporarily stop the window from opening, see |fidget.notification.suppress|.
---
---@return boolean closed_successfully Whether the window closed successfully.
function notification.close()
  return notification.window.guard(function()
    notification.window.close()
  end)
end

--- Clear notifications.
---
--- If the given `group_key` is `nil`, then all groups are cleared.
---
---@param group_key Key|nil  Which group to clear
function notification.clear(group_key)
  if group_key == nil then
    groups = {}
  else
    for idx, group in ipairs(groups) do
      if group.key == group_key then
        table.remove(groups, idx)
        break
      end
    end
  end
  if #groups == 0 then
    notification.window.guard(notification.window.close)
  end
end

--- Reset notification subsystem state.
function notification.reset()
  notification.clear()
  notification.poller:reset_error() -- Clear error if previously encountered one
end

--- The poller for the notification subsystem.
---@protected
notification.poller = poll.Poller {
  name = "notification",
  poll = function(self)
    groups = notification.model.tick(self:now(), groups)

    -- TODO: if not modified, don't re-render
    local v = notification.view.render(self:now(), groups)

    if #v.lines > 0 then
      if view_suppressed then
        return true
      end

      notification.window.guard(function()
        notification.window.set_lines(v.lines, v.highlights, v.width)
        notification.window.show(v.width, #v.lines)
      end)
      return true
    else
      if view_suppressed then
        return false
      end

      -- If we could not close the window, keep polling, i.e., keep trying to close the window.
      return not notification.close()
    end
  end
}

--- Dynamically add, overwrite, or delete a notification configuration.
---
--- Inherits missing keys from the default config.
---
---@param key       Key         Which config to set.
---@param config    Config|nil  What to set as config.
---@param overwrite boolean     Whether to overwrite existing config, if any.
---
---@see fidget.notification.Config
function notification.set_config(key, config, overwrite)
  if overwrite or not notification.options.configs[key] then
    notification.options.configs[key] = vim.tbl_extend("keep", config, notification.options.configs.default)
  end
end

--- Suppress whether the notification window is shown.
---
--- Pass `true` as argument to turn on suppression, or `false` to turn it off.
---
--- If no argument is given, suppression state is toggled.
---
---@param suppress boolean|nil Whether to suppress or toggle suppression
function notification.suppress(suppress)
  if suppress == nil then
    view_suppressed = not view_suppressed
  else
    view_suppressed = suppress
  end

  if view_suppressed then
    notification.close()
  end
end

return notification
