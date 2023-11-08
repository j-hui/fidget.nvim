local M = {}

local model = require("fidget.notification.model")
local window = require("fidget.notification.window")
local render = require("fidget.notification.render")

require("fidget.options")(M, {
  --- Rate at which Fidget should render notifications view.
  poll_rate = 10,

  window = window,
})

local origin_time = vim.fn.reltime()

--- Obtain the style specified by the level parameter of a .update() call,
--- reading from config if necessary.
---
---@param config  NotificationConfig
---@param level   Level | Style | nil
---@return        Style?
local function get_item_style(config, level)
  if type(level) == "number" then
    if level == vim.log.levels.INFO and config.info_style then
      return config.info_style
    elseif level == vim.log.levels.WARN and config.warn_style then
      return config.warn_style
    elseif level == vim.log.levels.ERROR and config.error_style then
      return config.error_style
    elseif level == vim.log.levels.HINT and config.hint_style then
      return config.hint_style
    end
  else
    return level
  end
end

--- Compute the expiry time based on the given TTL (from notify() options) and the default TTL (from config).
---@param ttl         number?
---@param default_ttl number
---@return            number expiry_time
local function compute_expiry(ttl, default_ttl)
  if not ttl or ttl == 0 then
    return vim.fn.reltimefloat(vim.fn.reltime(origin_time)) + default_ttl
  else
    return vim.fn.reltimefloat(vim.fn.reltime(origin_time)) + ttl
  end
end

--- Update the state of the notifications model.
---
--- The API of this function is based on that of vim.notify().
---
---@param msg     string?
---@param level   Level | Style | nil
---@param opts    NotificationOptions
function M.update(msg, level, opts)
  model.modified = true

  local group_key = opts.group ~= nil and opts.group or "default"
  local group = model.get_group(group_key)

  ---@type NotificationItem
  local item

  if opts.key ~= nil then
    -- key is given; look to see if item already exists
    for _, i in ipairs(group.items) do
      if i.key == opts.key then
        item = i
        break
      end
    end
  end

  if item == nil then
    -- Item does not already exist; create it
    if msg == nil then
      return -- cannot create item with no message
    end

    ---@type NotificationItem
    item = {
      key = opts.key,
      message = msg,
      annote = opts.annote,
      style = get_item_style(group.config, level) or group.config.annote_style,
      hidden = opts.hidden or false,
      expires_at = compute_expiry(opts.ttl, group.config.ttl),
      data = opts.data,
    }
    table.insert(group.items, item)
  else
    -- Item already exists, we just need to update it
    item.message = msg or item.message
    item.style = get_item_style(group.config, level) or item.style
    item.annote = opts.annote or item.annote
    item.hidden = opts.hidden or item.hidden
    item.expires_at = opts.ttl and compute_expiry(opts.ttl, group.config.ttl) or item.expires_at
    item.data = opts.data ~= nil and opts.data or item.data
  end
end

--- Send a notification to the Fidget notifications subsystem.
---
--- Can be used to override vim.notify(), e.g.,
---
---     vim.notify = require("fidget.notifications").notify
---
---@param msg     string?
---@param level   Level | Style | nil
---@param opts    NotificationOptions
function M.notify(msg, level, opts)
  M.update(msg, level, opts)
  M.start_polling()
end

--- Timestamp for current poll frame. Only valid while actively polling.
---@type number?
local now_sync = nil

--- Prune out all items (and groups) for which the ttl has elapsed.
---
---@param now number timestamp of current frame.
function M.tick(now)
  local new_groups = {}
  for _, group in ipairs(model.groups) do
    local new_items = {}
    for _, item in ipairs(group.items) do
      if item.expires_at > now then
        table.insert(new_items, item)
      else
      end
    end
    if #group.items > 0 then
      group.items = new_items
      table.insert(new_groups, group)
    else
    end
  end
  model.groups = new_groups
end

function M.poll()
  local now = now_sync or vim.fn.reltimefloat(vim.fn.reltime(origin_time))
  M.tick(now)
  local view = render.render_view(now, model.groups)
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
