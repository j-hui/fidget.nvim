---@mod fidget.progress.lsp Neovim LSP shim layer
local M                    = {}
local logger               = require("fidget.logger")

---@class ProgressMessage
---@field token       Key         Unique identifier used to accumulate updates
---@field title       string|nil  Name of the task in progress
---@field message     string|nil  Message describing the progress
---@field percentage  number|nil  How much of the progress is complete (out of 100)
---@field done        boolean     Whether this progress completed; ignore `percentage` if `done` is `true`
---@field cancellable boolean     Whether this task can be canceled (though doing so is unsupported with Fidget)
---@field lsp_client  table       LSP client table this message came from

--- Autocmd ID for the LSPAttach event.
---@type number?
local lsp_attach_autocmd   = nil

--- Built-in `$/progress` handler.
---@type function
local lsp_progress_handler = vim.lsp.handlers["$/progress"]

---@options progress.lsp [[
---@protected
--- Nvim LSP client options
M.options                  = {
  --- Configure the nvim's LSP progress ring buffer size
  ---
  --- Useful for avoiding progress message overflow when the LSP server blasts
  --- more messages than the ring buffer can handle (see #167).
  ---
  --- Leaves the progress ringbuf size at its default if this setting is 0 or
  --- less. Doesn't do anything for Neovim pre-v0.10.0.
  ---
  ---@type number
  progress_ringbuf_size = 0,

  --- Log `$/progress` handler invocations (for debugging)
  ---
  --- Works by wrapping `vim.lsp.handlers["$/progress"]` with Fidget's logger.
  --- Invocations are logged at the `vim.log.levels.INFO` level.
  ---
  --- This option exists primarily for debugging; leaving this set to `true` is
  --- not recommended.
  ---
  --- Since it works by overriding Neovim's existing `$/progress` handler, you
  --- should not use this function if you'd like Neovim to use your overriden
  --- `$/progress` handler! It will conflict with the handler that Fidget tries
  --- to install for logging purposes.
  log_handler = false,
}
---@options ]]

require("fidget.options").declare(M, "progress.lsp", M.options, function()
  if lsp_attach_autocmd ~= nil then
    vim.api.nvim_del_autocmd(lsp_attach_autocmd)
    lsp_attach_autocmd = nil
  end

  if vim.ringbuf and M.options.progress_ringbuf_size > 0 then
    logger.info("Setting LSP progress ringbuf size to", M.options.progress_ringbuf_size)
    lsp_attach_autocmd = vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        client.progress = vim.ringbuf(M.options.progress_ringbuf_size)
        client.progress.pending = {}
      end
    })
  end

  if M.options.log_handler then
    vim.lsp.handlers["$/progress"] = function(x, msg, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local tag = string.format("nvim $/progress handler for client %d (%s)", ctx.client_id, client.name)
      logger.info(tag, "invoked:", msg)

      local result = lsp_progress_handler(x, msg, ctx)

      if result ~= nil then
        logger.info(tag, "returned:", result)
      end
    end
  end
end)

--- Consumes LSP progress messages from each client.progress ring buffer.
---
--- Based on vim.lsp.status(), except this implementation does not format the
--- reports into strings.
---
---@return ProgressMessage[] progress_messages
---@see fidget.progress.lsp.ProgressMessage
function M.poll_for_messages()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    -- Issue being tracked in #177
    logger.warn("No active LSP clients to poll from (see issue #177)")
    return {}
  end

  local messages = {}
  for _, client in ipairs(clients) do
    local client_name = string.format("%s (%s)", client.id, client.name)
    local count = 0
    logger.info("Polling messages from", client_name)
    for progress in client.progress do
      count = count + 1
      local value = progress.value
      if type(value) == 'table' and value.kind then
        local message = {
          token = progress.token,
          title = value.title,
          message = value.message,
          percentage = value.done and nil or value.percentage,
          done = value.kind == "end",
          cancellable = value.cancellable or false,
          lsp_client = client,
        }
        logger.info("Got message from", client_name, ":", value)
        table.insert(messages, message)
      elseif progress.value ~= nil then
        -- Doesn't look like work done progress and can be in any format
        -- Ignore it as there is no sensible way to display it, but we log it
        logger.warn("Dropped message from client", client_name, "of type", type(value))
        logger.info("Dropped message contents:", vim.inspect(value))
      else -- progress.value == nil; nothing to display, nothing interesting to log
        -- Log at INFO level, not at WARN, because apparently some servers do
        -- send these kinds of messages spuriously.
        logger.info("Dropped nil message from client", client_name)
      end
    end
    logger.info("Processed", count, "messages from", client_name)
  end
  return messages
end

--- Register handler for LSP progress updates.
---
---@protected
---@param fn function
---@return number
function M.on_progress_message(fn)
  return vim.api.nvim_create_autocmd({ "LspProgress" }, {
    callback = fn,
    desc = "Fidget LSP progress handler",
  })
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
  ---@protected
  ---@return ProgressMessage[] progress_messages
  function M.poll_for_messages()
    local clients = vim.lsp.get_active_clients()
    if #clients == 0 then
      -- Issue being tracked in #177
      logger.warn("No active LSP clients to poll from (see issue #177)")
      return {}
    end

    local messages = {}
    local to_remove = {}
    for _, client in ipairs(clients) do
      local client_name = string.format("%s (%s)", client.id, client.name)
      local count = 0
      logger.info("Polling messages from", client_name)
      for token, value in pairs(client.messages.progress) do
        count = count + 1
        local seen = seen_messages[value]
        if not seen                                -- brand new table
            or seen.message ~= value.message       -- message changed
            or seen.percentage ~= value.percentage -- percentage changed
            or seen.done ~= value.done then        -- progress completed
          local message = {
            token = token,
            title = value.title,
            message = value.message,
            percentage = value.done and nil or value.percentage,
            done = value.done or false,
            cancellable = value.cancellable or false,
            lsp_client = client,
          }
          logger.info("Got message from", client_name, ":", value)
          table.insert(messages, message)

          if value.done then
            table.insert(to_remove, { client = client, token = token })
          else
            seen_messages[value] = { message = value.message, percentage = value.percentage, done = value.done }
          end
        end
      end
      logger.info("Processed", count, "messages from", client_name)
    end

    for _, item in ipairs(to_remove) do
      item.client.messages.progress[item.token] = nil
    end

    return messages
  end

  --- Register autocmd callback for LspProgressUpdate event (v0.8.0--v0.9.4).
  ---
  ---@protected
  ---@param fn function
  ---@return number
  function M.on_progress_message(fn)
    return vim.api.nvim_create_autocmd({ "User" }, {
      pattern = { "LspProgressUpdate" },
      callback = fn,
      desc = "Fidget LSP progress handler",
    })
  end
end

return M
