--- Fidget's LSP progress subsystem.
local M            = {}
M.display          = require("fidget.progress.display")
M.lsp              = require("fidget.progress.lsp")
local poll         = require("fidget.poll")
local notification = require("fidget.notification")
local logger       = require("fidget.logger")

--- Table of progress-related autocmds, used to ensure setup() re-entrancy.
local autocmds     = {}

--- Options related to LSP progress notification subsystem
require("fidget.options").declare(M, "progress", {
  --- How and when to poll for progress messages
  ---
  --- Set to `0` to immediately poll on each `LspProgress` event.
  ---
  --- Set to a positive number to poll for progress messages at the specified
  --- frequency (Hz, i.e., polls per second). Combining a slow `poll_rate`
  --- (e.g., `0.5`) with the `ignore_done_already` setting can be used to filter
  --- out short-lived progress tasks, de-cluttering notifications.
  ---
  --- Note that if too many LSP progress messages are sent between polls,
  --- Neovim's progress ring buffer will overflow and messages will be
  --- overwritten (dropped), possibly causing stale progress notifications.
  --- Workarounds include using the `progress.lsp.progress_ringbuf_size` option,
  --- or manually calling `fidget.notification.reset()` (see #167).
  ---
  --- Set to `false` to disable polling altogether; you can still manually poll
  --- progress messages by calling `fidget.progress.poll()`.
  ---
  ---@type number|false
  poll_rate = 0,

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

  --- Ignore new tasks that don't contain a message
  ---
  --- Some servers may send empty messages for tasks that don't actually exist.
  --- And if those tasks are never completed, they will become stale in Fidget.
  --- This option tells Fidget to ignore such messages unless the LSP server has
  --- anything meaningful to say. (See #171)
  ---
  --- Note that progress messages for new empty tasks will be dropped, but
  --- existing tasks will be processed to completion.
  ---
  ---@type boolean
  ignore_empty_message = false,

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
    return msg.lsp_client.name
  end,

  --- Clear notification group when LSP server detaches
  ---
  --- This option should be set to a function that, given a client ID number,
  --- returns the notification group to clear. No group will be cleared if the
  --- the function returns `nil`.
  ---
  --- The default setting looks up and returns the LSP client name, which is
  --- also used by `progress.notification_group`.
  ---
  --- Set this option to `nil` to disable this feature entirely (no `LspDetach`
  --- callback will be registered).
  ---
  ---
  ---@type (fun(client_id: number): NotificationKey)?
  clear_on_detach = function(client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    return client and client.name or nil
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
  -- Ensure setup() reentrancy
  for _, autocmd in pairs(autocmds) do
    vim.api.nvim_del_autocmd(autocmd)
  end
  autocmds = {}

  if M.options.poll_rate ~= false then
    autocmds["LspProgress"] = M.lsp.on_progress_message(function()
      if M.options.poll_rate > 0 then
        M.poller:start_polling(M.options.poll_rate)
      else
        M.poller:poll_once()
      end
    end)
  end

  if M.options.clear_on_detach then
    autocmds["LspDetach"] = vim.api.nvim_create_autocmd("LspDetach", {
      desc = "Fidget LSP detach handler",
      callback = function(args)
        M.on_detach(args.data.client_id)
      end,
    })
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
  if M.options.ignore_done_already and msg.done then
    update_only = true
  elseif M.options.ignore_empty_message and msg.message == nil then
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
    if #messages == 0 then
      logger.info("No LSP messages (that can be displayed)")
      return false
    end

    for _, msg in ipairs(messages) do
      -- Determine if we should ignore this message
      local ignore = false
      for _, lsp_name in ipairs(M.options.ignore) do
        -- NOTE: hopefully this loop isn't too expensive.
        -- But if it is, consider indexing by hash.
        if msg.lsp_client.name == lsp_name then
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

--- Called upon `LspDetach` event.
---
--- Clears notification group given by `options.clear_on_detach`.
---
---@param client_id number
function M.on_detach(client_id)
  local group_key = M.options.clear_on_detach(client_id)
  if group_key == nil then
    return
  end
  notification.clear(group_key)
end

return M
