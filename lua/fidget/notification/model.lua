--- This module encapsulates all the private (shared) model state used by the
--- notifications subsystem, and some helper functions.
---
--- Not part of the public API (but do what you want with it).
---
--- If this framework were to be expanded to support multiple concurrent
--- instances of the model, this module's contents would need to be cloned.
local M = {}

--- Get the notification group indexed by group_key; create one if none exists.
---
---@param   configs     { [Key]: NotificationConfig }
---@param   groups      NotificationGroup[]
---@param   group_key   Key
---@return              NotificationGroup group
local function get_group(configs, groups, group_key)
  for _, group in ipairs(groups) do
    if group.key == group_key then
      return group
    end
  end

  -- Group not found; create it and insert it into list of active groups.

  ---@type NotificationGroup
  local group = {
    key = group_key,
    items = {},
    config = configs[group_key] or configs.default
  }
  table.insert(groups, group)
  return group
end

--- Search for an item with the given key among a notification group.
---
---@param group NotificationGroup
---@param key Key
---@return NotificationItem?
local function find_item(group, key)
  if key == nil then
    return nil
  end


  for _, item in ipairs(group.items) do
    if item.key == key then
      return item
    end
  end

  -- No item with key was found
  return nil
end

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
local function compute_expiry(now, ttl, default_ttl)
  if not ttl or ttl == 0 then
    return now + default_ttl
  else
    return now + ttl
  end
end

--- Update the state of the notifications model.
---
--- The API of this function is based on that of vim.notify().
---
---@param now     number
---@param configs table<string, NotificationConfig>
---@param groups  NotificationGroup[]
---@param msg     string?
---@param level   Level | Style | nil
---@param opts    NotificationOptions
function M.update(now, configs, groups, msg, level, opts)
  local group_key = opts.group ~= nil and opts.group or "default"
  local group = get_group(configs, groups, group_key)
  local item = find_item(group, opts.key)

  if item == nil then
    -- Item doesn't yet exist; create new item and to insert into the group
    if msg == nil then
      return
    end
    ---@type NotificationItem
    local new_item = {
      key = opts.key,
      message = msg,
      annote = opts.annote,
      style = get_item_style(group.config, level) or group.config.annote_style,
      hidden = opts.hidden or false,
      expires_at = compute_expiry(now, opts.ttl, group.config.ttl),
      data = opts.data,
    }
    table.insert(group.items, new_item)
  else
    -- Item with the same key already exists; update it in place
    item.message = msg or item.message
    item.style = get_item_style(group.config, level) or item.style
    item.annote = opts.annote or item.annote
    item.hidden = opts.hidden or item.hidden
    item.expires_at = opts.ttl and compute_expiry(now, opts.ttl, group.config.ttl) or item.expires_at
    item.data = opts.data ~= nil and opts.data or item.data
  end
end

--- Prune out all items (and groups) for which the ttl has elapsed.
---
--- Updates each group in-place (i.e., removes items from them), but returns
--- a list of groups that still have items left.
---
---@param now number timestamp of current frame.
---@param groups NotificationGroup[]
---@return NotificationGroup[]
function M.tick(now, groups)
  local new_groups = {}
  for _, group in ipairs(groups) do
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
  return new_groups
end

return M
