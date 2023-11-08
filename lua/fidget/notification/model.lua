--- This module encapsulates all the private (shared) model state used by the
--- notifications subsystem, and some helper functions.
---
--- Not part of the public API (but do what you want with it).
---
--- If this framework were to be expanded to support multiple concurrent
--- instances of the model, this module's contents would need to be cloned.
local M = {}

--- The "model" of notifications: a list of notification groups.
---@type NotificationGroup[]
M.groups = {}

--- Configs, used to instantiate groups in the notification model.
---@type { [Key]: NotificationConfig }
M.configs = {
  default = {
    ttl = 1.5,
    name_style = "name",
    icon_style = "icon",
    msg_style = "msg",
    annote_style = "annote",
  }
}

--- Track changes to model state. Used to avoid unnecessary rendering.
---@type boolean
M.modified = false

--- Get the notification group indexed by group_key; create one if none exists.
---
---@param   group_key   Key
---@return              NotificationGroup group
function M.get_group(group_key)
  for _, group in ipairs(M.groups) do
    if group.key == group_key then
      return group
    end
  end

  ---@type NotificationGroup
  local group = {
    key = group_key,
    items = {},
    config = M.configs[group_key] or M.configs.default
  }
  table.insert(M.groups, group)
  return group
end

return M
