local M       = {}
local spinner = require("fidget.spinner")

--- Default format_message implementation.
---
---@param msg ProgressMessage
---@return string progress_notification_message
function M.default_format_message(msg)
  local message = msg.message
  if not message then
    message = msg.done and "Completed" or "In progress..."
  end
  if msg.percentage ~= nil then
    message = string.format("%s (%.0f%%)", message, msg.percentage)
  end
  return message
end

--- Options related to how LSP progress messages are displayed as notifications
require("fidget.options").declare(M, "progress.display", {
  --- How many LSP messages to show at once
  ---
  --- If `false`, no limit.
  ---
  --- This is used to configure each LSP notification group, so by default, this
  --- is a per-server limit.
  ---
  ---@type number | false
  render_limit = 16,

  --- How long a message should persist after completion
  ---
  --- Set to `0` to use notification group config default, and `math.huge` to
  --- show notification indefinitely (until overwritten).
  ---
  --- Measured in seconds.
  ---
  ---@type number
  done_ttl = 3,

  --- Icon shown when all LSP progress tasks are complete
  ---
  ---@type string | Manga
  done_icon = "✔",

  --- Highlight group for completed LSP tasks
  ---
  ---@type string
  done_style = "Constant",

  --- How long a message should persist when in progress
  ---
  --- Set to `0` to use notification group config default, and `math.huge` to
  --- show notification indefinitely (until overwritten).
  ---
  --- Measured in seconds.
  ---
  ---@type number
  progress_ttl = math.huge,

  --- Icon shown when LSP progress tasks are in progress
  ---
  ---@type string | Manga
  progress_icon = { pattern = "dots", period = 1 },

  --- Highlight group for in-progress LSP tasks
  ---
  ---@type string
  progress_style = "WarningMsg",

  --- Highlight group for group name (LSP server name)
  ---
  ---@type string
  group_style = "Title",

  --- Highlight group for group icons
  ---
  ---@type string
  icon_style = "Question",

  --- Ordering priority for LSP notification group
  ---
  ---@type number?
  priority = 30,

  --- How to format a progress message
  ---
  --- Example:
  ---
  --- ```lua
  --- format_message = function(msg)
  ---   if string.find(msg.title, "Indexing") then
  ---     return nil -- Ignore "Indexing..." progress messages
  ---   end
  ---   if msg.message then
  ---     return msg.message
  ---   else
  ---     return msg.done and "Completed" or "In progress..."
  ---   end
  --- end
  --- ```
  ---
  ---@type fun(msg: ProgressMessage): string
  format_message = M.default_format_message,

  --- How to format a progress annotation
  ---
  ---@type fun(msg: ProgressMessage): string
  format_annote = function(msg)
    return msg.title
  end,

  --- How to format a progress notification group's name
  ---
  --- Example:
  ---
  --- ```lua
  --- format_group_name = function(group)
  ---   return "lsp:" .. tostring(group)
  --- end
  --- ```
  ---
  ---@type fun(group: NotificationKey): NotificationDisplay
  format_group_name = tostring,

  --- Override options from the default notification config
  ---
  --- Keys of the table are each notification group's `key`.
  ---
  --- Example:
  ---
  --- ```lua
  --- overrides = {
  ---   hls = {
  ---     name = "Haskell Language Server",
  ---     priority = 60,
  ---     icon = fidget.progress.display.for_icon(fidget.spinner.animate("triangle", 3), "💯"),
  ---   },
  ---   rust_analyzer = {
  ---     name = "Rust Analyzer",
  ---     icon = fidget.progress.display.for_icon(fidget.spinner.animate("arrow", 2.5), "🦀"),
  ---   },
  --- }
  --- ```
  ---
  ---@type { [NotificationKey]: NotificationConfig }
  overrides = {
    rust_analyzer = { name = "rust-analyzer" },
  }
})

--- Construct the icon display function, based on two animation functions.
---
---@param progress  string|Anime progress icon/animation function
---@param done      string|Anime completion icon/animation function
---@return NotificationDisplay icon_display
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
---@param group NotificationKey
---@return NotificationConfig
function M.make_config(group)
  local progress = M.options.progress_icon
  if type(progress) == "table" then
    progress = spinner.animate(progress.pattern, progress.period)
  end

  local done = M.options.done_icon
  if type(done) == "table" then
    done = spinner.animate(done.pattern, done.period)
  end

  local config = {
    name = M.options.format_group_name(group),
    icon = M.for_icon(progress, done),
    ttl = M.options.done_ttl,
    render_limit = M.options.render_limit or nil,
    group_style = M.options.group_style,
    icon_style = M.options.icon_style,
    annote_style = M.options.progress_style,
    warn_style = M.options.progress_style,
    info_style = M.options.done_style,
    priority = M.options.priority,
  }

  if M.options.overrides[group] then
    config = vim.tbl_extend("force", config, M.options.overrides[group])
  end

  return config
end

return M
