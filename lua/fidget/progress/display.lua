local M       = {}
local spinner = require("fidget.spinner")

require("fidget.options")(M, {
  --- How long a progress notification should persist after it is complete.
  ---
  --- Set to 0 to use notification group config default.
  ---
  ---@type number
  done_ttl = 3,

  --- Icon shown when LSP tasks are complete.
  ---
  ---@type string|Manga
  done_icon = "✔",

  --- Name of annotation highlight group when LSP tasks are complete.
  ---
  ---@type string
  done_style = "Constant",

  --- How long a progress notification should persist while it is in progress.
  ---
  --- Set to 0 to use notification group config default.
  ---
  ---@type number
  progress_ttl = math.huge,

  --- Icon shown when LSP tasks are in progress.
  ---
  ---@type string|Manga
  progress_icon = { pattern = "dots", period = 1 },

  --- Name of annotation highlight group when LSP tasks are in progress.
  ---
  ---@type string
  progress_style = "WarningMsg",

  --- Name of highlight group used for notification group title.
  ---
  ---@type string
  group_style = "Title",

  --- Name of highlight group used for notification group icon.
  ---
  ---@type string
  icon_style = "Question",

  --- Priority of LSP progress message notifications.
  ---
  ---@type number?
  priority = 30,

  --- Callback to format a ProgressMessage into a notification message.
  ---
  ---@param msg ProgressMessage
  ---@return string notification_message
  format_message = function(msg)
    local message = msg.message
    if not message then
      message = msg.done and "Completed" or "In progress..."
    end
    if msg.percentage ~= nil then
      message = string.format("%s (%.0f%%)", message, msg.percentage)
    end
    return message
  end,

  --- Callback to format a ProgressMessage into a notification annotation.
  ---
  ---@param msg ProgressMessage
  ---@return string notification_annote
  format_annote = function(msg)
    return msg.title
  end,

  --- Callback to generate the group name from the key of a group.
  ---
  ---@param group_key any
  ---@return Display
  format_group_name = function(group_key)
    return tostring(group_key)
  end,

  --- Notification configs used to override options of the default configuration
  --- on a per-LSP server basis.
  ---
  ---@type { [any]: NotificationConfig }
  overrides = {
    rust_analyzer = { name = "rust-analyzer" },
  }
})

--- Construct the icon display function, based on two animation functions.
---
---@param progress  string|Anime progress icon/animation function
---@param done      string|Anime completion icon/animation function
---@return Display icon_display
function M.for_icon(progress, done)
  return function(now, items)
    for _, item in ipairs(items) do
      if not item.data then
        -- Still in progress
        return type(progress) == "string" and progress or progress(now)
      end
    end
    return type(done) == "string" and done or done(now)
  end
end

--- Create the config for a language server indexed by the given group key.
---@param group_key any
---@return NotificationConfig
function M.make_config(group_key)
  local progress = M.options.progress_icon
  if type(progress) == "table" then
    progress = spinner.animate(progress.pattern, progress.period)
  end

  local done = M.options.done_icon
  if type(done) == "table" then
    done = spinner.animate(done.pattern, done.period)
  end

  local config = {
    name = M.options.format_group_name(group_key),
    icon = M.for_icon(progress, done),
    ttl = M.options.done_ttl,
    group_style = M.options.group_style,
    icon_style = M.options.icon_style,
    annote_style = M.options.progress_style,
    warn_style = M.options.progress_style,
    info_style = M.options.done_style,
    priority = M.options.priority,
  }

  if M.options.overrides[group_key] then
    config = vim.tbl_extend("force", config, M.options.overrides[group_key])
  end

  return config
end

return M
