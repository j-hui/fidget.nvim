--- Fidget's LSP progress subsystem.
local M            = {}
M.display          = require("fidget.progress.display")
M.lsp              = require("fidget.progress.lsp")
local logger       = require("fidget.logger")
local notification = require("fidget.notification")

--- Options related to LSP progress notification subsystem
require("fidget.options")(M, {
  --- How frequently to poll for progress messages
  ---
  --- Set to 0 to disable polling; you can still manually poll progress messages
  --- by calling `fidget.progress.poll()`.
  ---
  --- Measured in Hertz (frames per second).
  ---
  ---@type number
  poll_rate = 5,

  --- How to get a progress message's notification group key
  ---
  --- Set this to return a constant to group all LSP progress messages together,
  --- e.g.,
  ---
  --- ```lua
  --- notification_group = function(msg)
  ---   -- N.B. you may also want to configure this group key ("lsp_progress")
  ---   -- using progress.display.overrides or notification.configs
  ---   return "lsp_progress"
  --- end
  --- ```
  ---
  ---@type fun(msg: ProgressMessage): NotificationKey
  notification_group = function(msg)
    return msg.lsp_name
  end,

  --- List of LSP servers to ignore
  ---
  --- Example:
  ---
  --- ```lua
  --- ignore = { "rust_analyzer" }
  --- ```
  ---
  ---@type NotificationKey[]
  ignore = {},

  display = M.display,
}, function()
  if M.options.poll_rate > 0 then
    -- TODO: make idempotent
    M.lsp.on_progress_message(M.start_polling)
  end
end)

--- Whether progress message updates are suppressed.
local progress_suppressed = false

--- Cache of generated LSP notification group configs.
---
---@type { [NotificationKey]: NotificationConfig }
local loaded_configs = {}

--- Lazily load the notification configuration for some progress message.
---
---@param msg ProgressMessage
function M.load_config(msg)
  local group = M.options.notification_group(msg)
  if loaded_configs[group] then
    return
  end

  local config = M.display.make_config(group)

  notification.set_config(group, config, false)
end

---@param msg ProgressMessage
---@return string?
---@return number
---@return NotificationOptions
function M.format_progress(msg)
  local group = M.options.notification_group(msg)
  local message = M.options.display.format_message(msg)
  local annote = M.options.display.format_annote(msg)

  return message, msg.done and vim.log.levels.WARN or vim.log.levels.INFO, {
    key = msg.token,
    group = group,
    annote = annote,
    ttl = msg.done and 0 or M.display.options.progress_ttl, -- Use config default when done
    data = msg.done,                                        -- use data to convey whether this task is done
  }
end

--- Poll for messages and feed them to the fidget notifications subsystem.
function M.poll()
  if progress_suppressed then
    return false
  end

  local messages = M.lsp.poll_for_messages()
  if messages == nil then
    return false
  end

  for _, msg in ipairs(messages) do
    -- NOTE: hopefully this loop isn't too expensive.
    -- But if it is, consider indexing by hash.
    local ignore = false
    for _, lsp_name in ipairs(M.options.ignore) do
      if msg.lsp_name == lsp_name then
        ignore = true
      end
    end
    if not ignore then
      M.load_config(msg)
      notification.notify(M.format_progress(msg))
    end
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
  logger.info("starting progress poller")
  poll_count = poll_count + 1
  local done, timer, delay = false, vim.loop.new_timer(), math.ceil(1000 / M.options.poll_rate)
  timer:start(15, delay, vim.schedule_wrap(function() -- Note: hard-coded 15ms attack
    if done then return end
    if not M.poll() then
      logger.info("stopping progress poller")
      timer:stop()
      timer:close()
      done = true
      poll_count = poll_count - 1
    end
  end)
  )
end

--- Suppress consumption of progress messages.
---
--- Pass `false` as argument to turn off suppression.
---
--- If no argument is given, suppression state is toggled.
---@param suppress boolean? Whether to suppress or toggle suppression
function M.suppress(suppress)
  if suppress == nil then
    progress_suppressed = not progress_suppressed
  else
    progress_suppressed = suppress
  end
end

return M
