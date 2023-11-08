--- Fidget's LSP progress subsystem.
local M            = {}
local logger       = require("fidget.logger")
local notification = require("fidget.notification")

---@class ProgressMessage
---@field token       any       Unique identifier used to accumulate updates
---@field title       string?   Name of the task in progress
---@field message     string?   Message describing the progress
---@field percentage  number?   How much of the progress is complete (out of 100).
---@field done        boolean   Whether this progress completed. Ignore percentage if done is true.
---@field cancellable boolean   Whether this task can be cancelled (though doing so is unsupported with Fidget)
---@field lsp_name    string    Name of the LSP client that sent this message
---@field lsp_id      number    ID of the LSP client that sent this message

require("fidget.options")(M, {
  --- Rate at which Fidget should poll for progress messages.
  poll_rate = 5,

  --- Callback used to format a ProgressMessage into a notification message.
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

  --- Callback used to format a ProgressMessage into a notification annotation.
  ---
  ---@param msg ProgressMessage
  ---@return string notification_annote
  format_annote = function(msg)
    return msg.title
  end,
}, function()
  M.on_progress_message(M.start_polling)
end)

--- Consumes LSP progress messages from each client.progress ring buffer.
---
--- Based on vim.lsp.status(), except this implementation does not format the
--- reports into strings.
---
---@return ProgressMessage[]? # LSP progress messages received since last called.
function M.poll_for_messages()
  local messages = {}
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    for progress in client.progress do
      local value = progress.value
      if type(value) == 'table' and value.kind then
        local message = {
          token = progress.token,
          title = value.title,
          message = value.message,
          percentage = value.done and nil or value.percentage,
          done = value.kind == "end",
          cancellable = value.cancellable or false,
          lsp_name = client.name,
          lsp_id = client.id,
        }
        table.insert(messages, message)
      end
      -- else: Doesn't look like work done progress and can be in any format
      -- Just ignore it as there is no sensible way to display it
    end
  end
  return #messages > 0 and messages or nil
end

function M.on_progress_message(fn)
  vim.api.nvim_create_autocmd({ "LspProgress" }, { callback = fn })
end

if not vim.lsp.status then
  -- We're probably not on v0.10.0 yet (i.e., #23958 has yet to land).
  -- Overide with compatibility layer that supports v0.8.0+.

  --- An ephemeron table to track which progress messages we've already seen.
  ---
  --- With weak keys, once a message is removed from the progress table, the Lua
  --- garbage collector will also get rid of it from here.
  local seen_messages = setmetatable({}, { __mode = 'k' })

  --- Based on [vim.lsp.util.get_progress_messages()][get_progress_messages] as it
  --- was implemented in Neovim 0.8.0--0.9.4.
  ---
  --- Adapted with the following changes:
  --- - report.title is simply nil if there is no title
  --- - no need to set report.progress = true
  --- - tokens, client names, and client_id are included in each returned message
  --- - only report new messages that haven't
  ---
  --- Note that to remain compatible with get_progress_messages(), this
  --- implementation does not consume progress messages, i.e., non-done messages
  --- are left in the `client.messages.progress` table. Instead, it uses an
  --- ephemeron table (seen_messages) along with some heuristics to determine
  --- whether the message should be emitted. While this is somewhat slow, it's
  --- also being phased out; get_progress_messages() is deprecated in v0.10.0 and
  --- replaced by [vim.lsp.status()][lsp-status-pr], whose ring buffer gives
  --- consume semantics.
  ---
  --- [get_progress_messages]: https://github.com/neovim/neovim/blob/v0.9.4/runtime/lua/vim/lsp/util.lua#L354-L385
  --- [lsp-status-pr]: https://github.com/neovim/neovim/pull/23958
  ---
  ---@return ProgressMessage[]? # LSP progress messages received since last called.
  function M.poll_for_messages()
    local messages = {}
    local to_remove = {}

    for _, client in ipairs(vim.lsp.get_active_clients()) do
      for token, ctx in pairs(client.messages.progress) do
        local seen = seen_messages[ctx]
        if not seen                              -- brand new table
            or seen.message ~= ctx.message       -- message changed
            or seen.percentage ~= ctx.percentage -- percentage changed
            or seen.done ~= ctx.done then        -- progress completed
          local message = {
            token = token,
            title = ctx.title,
            message = ctx.message,
            percentage = ctx.done and nil or ctx.percentage,
            done = ctx.done or false,
            cancellable = ctx.cancellable or false,
            lsp_name = client.name,
            lsp_id = client.id,
          }
          table.insert(messages, message)

          if ctx.done then
            table.insert(to_remove, { client = client, token = token })
          else
            seen_messages[ctx] = { message = ctx.message, percentage = ctx.percentage, done = ctx.done }
          end
        end
      end
    end

    for _, item in ipairs(to_remove) do
      item.client.messages.progress[item.token] = nil
    end

    return #messages > 0 and messages or nil
  end

  --- Register autocmd callback for LspProgressUpdate event (v0.8.0--v0.9.4).
  function M.on_progress_message(fn)
    vim.api.nvim_create_autocmd({ "User" }, {
      pattern = { "LspProgressUpdate" },
      callback = fn,
    })
  end
end

---@param msg ProgressMessage
---@return string?
---@return number
---@return NotificationOptions
function M.format_progress(msg)
  local message = M.options.format_message(msg)
  local annote = M.options.format_annote(msg)

  -- TODO: add options to group LSP messages into a single group

  return message, vim.log.levels.INFO, {
    key = msg.token,
    group = msg.lsp_name,
    annote = annote,
    ttl = msg.done and 0 or math.huge,
    data = msg.done, -- use data to convey whether this task is done
  }
end

--- Poll for messages and feed them to the fidget notifications subsystem.
function M.poll()
  local messages = M.poll_for_messages()
  if messages == nil then
    return false
  end

  for _, msg in ipairs(messages) do
    notification.notify(M.format_progress(msg))
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

return M
