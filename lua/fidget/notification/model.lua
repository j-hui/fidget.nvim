---Fidget notification abstract state (internal)
---
--- Type definitions and helper methods for the notifications model
--- (i.e., its abstract state).
---
--- Note that this model exists separately from the view for several reasons:
--- (1) to make debugging and testing easier;
--- (2) to accumulate repeated, asynchronous in-place-updating notifications,
---     and avoid building strings for no reason; and
--- (3) to enable fine-grained cacheing of rendered elements.
---
--- Types and functions defined in this module are considered private, and won't
--- be added to code documentation.
local M      = {}
local logger = require("fidget.logger")
local poll   = require("fidget.poll")

--- The abstract state of the notifications subsystem.
---@class State
---@field groups          Group[]         active notification groups
---@field view_suppressed boolean         whether the notification window is suppressed
---@field removed         HistoryItem[]   ring buffer of removed notifications, kept around for history
---@field removed_cap     number          capacity of removed ring buffer
---@field removed_first   number          index of first item in removed ring buffer (1-indexed)

--- A collection of notification Items.
---@class Group
---@field key           Key     used to distinguish this group from others
---@field config        Config  configuration for this group
---@field items         Item[]  items displayed in the group

---@class HistoryExtra
---@field removed   boolean
---@field group_key Key
---@field group_name string|nil
---@field group_icon string|nil

--- Get the notification group indexed by group_key; create one if none exists.
---
---@param   configs     table<Key, Config>
---@param   groups      Group[]
---@param   group_key   Key
---@return              Group      group
---@return              number|nil new_index
local function get_group(configs, groups, group_key)
  for _, group in ipairs(groups) do
    if group.key == group_key then
      return group, nil
    end
  end

  -- Group not found; create it and insert it into list of active groups.

  ---@type Group
  local group = {
    key = group_key,
    items = {},
    config = configs[group_key] or configs.default
  }
  table.insert(groups, group)
  return group, #groups
end

--- Add item to the removed history
---
---@param state State
---@param now   number
---@param group Group
---@param item  Item
local function add_removed(state, now, group, item)
  if not item.skip_history then
    local group_name = group.config.name
    if type(group_name) == "function" then
      group_name = group_name(now, group.items)
    end

    local group_icon = group.config.icon
    if type(group_icon) == "function" then
      group_icon = group_icon(now, group.items)
    end

    ---@cast item HistoryItem
    item.last_updated = poll.unix_time(now)
    item.removed = true
    item.group_key = group.key
    item.group_name = group_name
    item.group_icon = group_icon

    state.removed[state.removed_first] = item
    state.removed_first = (state.removed_first % state.removed_cap) + 1
  end
end

--- Promote an item to a history item.
---
---@param item    Item
---@param extra   HistoryExtra
---@return        HistoryItem
local function item_to_history(item, extra)
  ---@type HistoryItem
  item = vim.tbl_extend("force", item, extra)
  item.last_updated = poll.unix_time(item.last_updated)
  return item
end

--- Whether an item matches the filter.
---
---@param filter HistoryFilter
---@param now number
---@param item Item
---@return boolean
local function matches_filter(filter, now, item)
  if filter.since and now - filter.since < item.last_updated then
    return false
  end

  if filter.before and now - filter.before > item.last_updated then
    return false
  end

  return true
end

--- Search for an item with the given key among a notification group.
---
---@param group Group
---@param key Key
---@return Item|nil
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

--- Obtain the style specified by the level parameter of a .update(),
--- reading from config if necessary.
---
---@param config  Config
---@param level   number|string|nil
---@return        string|nil
local function style_from_level(config, level)
  if type(level) == "number" then
    if level == vim.log.levels.INFO and config.info_style then
      return config.info_style
    elseif level == vim.log.levels.WARN and config.warn_style then
      return config.warn_style
    elseif level == vim.log.levels.ERROR and config.error_style then
      return config.error_style
    elseif level == vim.log.levels.DEBUG and config.debug_style then
      return config.debug_style
    end
  else
    return level
  end
end

--- Obtain the annotation from the specified level of an .update() call.
---
---@param config Config
---@param level  number|string|nil
---@return string|nil
local function annote_from_level(config, level)
  if type(level) == "number" then
    if level == vim.log.levels.INFO then
      return config.info_annote or "INFO"
    elseif level == vim.log.levels.WARN then
      return config.warn_annote or "WARN"
    elseif level == vim.log.levels.ERROR then
      return config.error_annote or "ERROR"
    elseif level == vim.log.levels.DEBUG then
      return config.debug_annote or "DEBUG"
    end
  else
    return nil
  end
end

--- Compute the expiry time based on the given TTL (from notify() options) and the default TTL (from config).
---@param ttl         number|nil
---@param default_ttl number|nil
---@return            number expiry_time
local function compute_expiry(now, ttl, default_ttl)
  if not ttl or ttl == 0 then
    return now + (default_ttl or 3)
  else
    return now + ttl
  end
end

--- Update the state of the notifications model.
---
--- The API of this function is based on that of vim.notify().
---
---@protected
---@param now     number
---@param configs table<string, Config>
---@param state   State
---@param msg     string|nil
---@param level   Level|nil
---@param opts    Options|nil
function M.update(now, configs, state, msg, level, opts)
  opts = opts or {}
  local group_key = opts.group ~= nil and opts.group or "default"
  local group, new_index = get_group(configs, state.groups, group_key)
  local item = find_item(group, opts.key)

  if item == nil then
    -- Item doesn't yet exist; create new item and to insert into the group
    if msg == nil or opts.update_only then
      if new_index then
        table.remove(state.groups, new_index)
      end
      return
    end

    local skip_history = false
    if group.config.skip_history ~= nil then
      skip_history = group.config.skip_history
    end
    if opts.skip_history ~= nil then
      skip_history = opts.skip_history
    end
    ---@cast skip_history boolean

    ---@type Item
    local new_item = {
      key = opts.key,
      group_key = group_key,
      message = msg,
      annote = opts.annote or annote_from_level(group.config, level),
      style = style_from_level(group.config, level) or group.config.annote_style or "Question",
      hidden = opts.hidden or false,
      expires_at = compute_expiry(now, opts.ttl, group.config.ttl),
      skip_history = skip_history,
      removed = false,
      last_updated = now,
      data = opts.data,
    }
    if group.config.update_hook then
      group.config.update_hook(new_item)
    end
    table.insert(group.items, new_item)
  else
    -- Item with the same key already exists; update it in place
    item.message = msg or item.message
    item.style = style_from_level(group.config, level) or item.style
    item.annote = opts.annote or annote_from_level(group.config, level) or item.annote
    item.hidden = opts.hidden or item.hidden
    item.expires_at = opts.ttl and compute_expiry(now, opts.ttl, group.config.ttl) or item.expires_at
    item.skip_history = opts.skip_history or item.skip_history
    item.last_updated = now
    item.data = opts.data ~= nil and opts.data or item.data
    if group.config.update_hook then
      group.config.update_hook(item)
    end
  end

  if new_index then
    -- NOTE: we use vim.fn.sort() here because it is stable.
    -- :h sort() docs claim that it does so in-place, but it doesn't.
    state.groups = vim.fn.sort(state.groups, function(a, b)
      return (a.config.priority or 50) - (b.config.priority or 50)
    end)
  end
end

--- Remove an item from a particular group.
---
---@param state     State
---@param now       number
---@param group_key Key
---@param item_key  Key
---@return boolean successfully_removed
function M.remove(state, now, group_key, item_key)
  for g, group in ipairs(state.groups) do
    if group.key == group_key then
      for i, item in ipairs(group.items) do
        if item.key == item_key then
          -- Note that it should be safe to perform destructive updates to the
          -- arrays here since we're no longer iterating.
          table.remove(group.items, i)
          add_removed(state, now, group, item)
          if #group.items == 0 then
            table.remove(state.groups, g)
          end
          return true
        end
      end
      return false -- Found group, but didn't find item
    end
  end
  return false -- Did not find group
end

--- Clear active notifications.
---
--- If the given `group_key` is `nil`, then all groups are cleared. Otherwise,
--- only that notification group is cleared.
---
---@param state     State
---@param now       number
---@param group_key Key|nil
function M.clear(state, now, group_key)
  if group_key == nil then
    for _, group in ipairs(state.groups) do
      for _, item in ipairs(group.items) do
        add_removed(state, now, group, item)
      end
    end
    state.groups = {}
  else
    for idx, group in ipairs(state.groups) do
      if group.key == group_key then
        for _, item in ipairs(group.items) do
          add_removed(state, now, group, item)
        end
        table.remove(state.groups, idx)
        -- We assume group keys are unique
        break
      end
    end
  end
end

--- Prune out all items (and groups) for which the ttl has elapsed.
---
---@protected
---@param now number timestamp of current frame.
---@param state  State
function M.tick(now, state)
  local new_groups = {}
  for _, group in ipairs(state.groups) do
    local new_items = {}
    for _, item in ipairs(group.items) do
      if item.expires_at > now then
        table.insert(new_items, item)
      else
        add_removed(state, now, group, item)
      end
    end
    if #group.items > 0 then
      group.items = new_items
      table.insert(new_groups, group)
    else
    end
  end
  state.groups = new_groups
end

--- Generate a notifications history according to the provided filter.
---
--- The results are not sorted.
---
---@param state   State
---@param filter  HistoryFilter
---@param now     number
---@return        HistoryItem[] history
function M.make_history(state, now, filter)
  ---@type Item[]
  local history = {}

  if filter.include_active ~= false then
    for _, group in ipairs(state.groups) do
      if filter.group_key == nil or group.key == filter.group_key then
        for _, item in ipairs(group.items) do
          if not item.skip_history and matches_filter(filter, now, item) then
            local group_name = group.config.name
            if type(group_name) == "function" then
              group_name = group_name(now, group.items)
            end

            local group_icon = group.config.icon
            if type(group_icon) == "function" then
              group_icon = group_icon(now, group.items)
            end

            table.insert(history, item_to_history(item, {
              removed = false,
              group_key = group.key,
              group_name = group_name,
              group_icon = "",
            }))
          end
        end
        if filter.group_key ~= nil then
          -- No need to search other groups, we assume keys are unique
          break
        end
      end
    end
  end

  if filter.include_removed ~= false then
    for _, item in ipairs(state.removed) do
      if matches_filter(filter, now, item) then
        -- NOTE: we aren't deep-copying here---not sure it's necessary.
        table.insert(history, item)
      end
    end
  end

  return history
end

--- Clear notifications history, according to the specified filter.
---
--- Removes items that match the filter; equivalently, preserves items that do
--- not match the filter.
---
---@param state   State
---@param now     number
---@param filter  HistoryFilter
function M.clear_history(state, now, filter)
  if filter.include_removed == false then
    logger.warn("filter does not make any sense for clearing history:", vim.inspect(filter))
    return
  end

  local new_removed = {}

  if state.removed[state.removed_first] ~= nil then
    -- History has already wrapped around
    for i = state.removed_first, state.removed_cap do
      local item = state.removed[i]
      if not matches_filter(filter, now, item) then
        table.insert(new_removed, item)
      end
    end
  end

  for i = 1, state.removed_first - 1 do
    local item = state.removed[i]
    if item == nil then
      -- Reached end of ring buffer
      break
    end
    if not matches_filter(filter, now, item) then
      table.insert(new_removed, item)
    end
  end

  state.removed = new_removed
  state.removed_first = #new_removed + 1
end

return M
