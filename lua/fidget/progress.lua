--- Fidget's LSP progress subsystem.
local M            = {}
M.display          = require("fidget.progress.display")
M.lsp              = require("fidget.progress.lsp")
local poll         = require("fidget.poll")
local notification = require("fidget.notification")
local logger       = require("fidget.logger")

--- Used to ensure only a single autocmd callback exists.
---@type number?
local autocmd_id   = nil

--- Options related to LSP progress notification subsystem
require("fidget.options").declare(M, "progress", {
  --- How frequently to poll for progress messages
  ---
  --- Set to 0 to disable polling; you can still manually poll progress messages
  --- by calling `fidget.progress.poll()`.
  ---
  --- Measured in Hertz (frames per second).
  ---
  ---@type number
  poll_rate = 5,

  --- Suppress new messages while in insert mode
  ---
  --- Note that progress messages for new tasks will be dropped, but existing
  --- tasks will be processed to completion.
  ---
  ---@type boolean
  suppress_on_insert = false,

  --- Ignore new tasks that are already complete
  ---
  --- This is useful if you want to avoid excessively bouncy behavior, and only
  --- seeing notifications for long-running tasks. Works best when combined with
  --- a low `poll_rate`.
  ---
  ---@type boolean
  ignore_done_already = false,

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
  lsp = M.lsp,
}, function()
  if autocmd_id ~= nil then
    vim.api.nvim_del_autocmd(autocmd_id)
    autocmd_id = nil
  end
  if M.options.poll_rate > 0 then
    autocmd_id = M.lsp.on_progress_message(function()
      M.poller:start_polling(M.options.poll_rate)
    end)
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

  local update_only = false
  if M.options.suppress_done_already and msg.done then
    update_only = true
  elseif M.options.suppress_on_insert and string.find(vim.fn.mode(), "i") then
    update_only = true
  end

  return message, msg.done and vim.log.levels.INFO or vim.log.levels.WARN, {
    key = msg.token,
    group = group,
    annote = annote,
    update_only = update_only,
    ttl = msg.done and 0 or M.display.options.progress_ttl, -- Use config default when done
    data = msg.done,                                        -- use data to convey whether this task is done
  }
end

--- Poll for progress messages to feed to the fidget notifications subsystem.
M.poller = poll.Poller {
  name = "progress",
  poll = function()
    if progress_suppressed then
      return false
    end

    local messages = M.lsp.poll_for_messages()
    if messages == nil then
      return false
    end

    for _, msg in ipairs(messages) do
      -- Determine if we should ignore this message
      local ignore = false
      for _, lsp_name in ipairs(M.options.ignore) do
        -- NOTE: hopefully this loop isn't too expensive.
        -- But if it is, consider indexing by hash.
        if msg.lsp_name == lsp_name then
          ignore = true
          logger.info("Ignoring LSP progress message:", msg)
          break
        end
      end
      if not ignore then
        logger.info("Notifying LSP progress message:", msg)
        M.load_config(msg)
        notification.notify(M.format_progress(msg))
      end
    end
    return true
  end
}

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
