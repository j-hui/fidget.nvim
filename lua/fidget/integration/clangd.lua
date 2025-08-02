local M = {}

---@options integration.clangd [[
--- clangd integration
M.options = {
  --- Integrate with clangd LSP clangdFileStatus
  --- Show clangd parsing progress
  --- init_options.clangdFileStatus = true must be set in clangd LSP config
  --- Example using lspconfig:
  --- lspconfig.clangd.setup {
  ---   init_options = {
  ---     clangdFileStatus = true
  ---   }
  --- }
  --- Note: if enabled, vim.lsp.handlers["textDocument/clangd.fileStatus"] will be hooked
  --- You can use the handler of this sub module directly
  ---@type boolean
  enable = false,

  --- Do not show notification if clangd isn't busy
  --- for more than this number of ms
  ---@type integer
  notification_delay = 500,

  --- Annotation string shown next to the message
  ---@type string
  annote = "clangd",
}

local notify = require"fidget.notification".notify
local file_status = {}
local function stop_timer(status)
  if status.timer then
    status.timer:stop()
    status.timer:close()
    status.timer = nil
  end
end

M.handler = function(err, result, ctx, config)
  if not result.state then return end
  local key = result.uri
  local message = result.state
  local opts = {
    key = key,
    group = "clangd.fileStatus",
    annote = M.options.annote,
    ttl = math.huge,
  }

  if not file_status[key] then
    file_status[key] = {
      message = message,
      complete = false,
      timer = nil,
      busy = false,
    }
  end
  local status = file_status[key]
  status.message = message

  if message == "idle" then
    stop_timer(status)
    status.complete = true
    if not status.busy then
      -- no notification displayed
      status.busy = false
      return
    end
    -- update notification
    status.busy = false
    message = "Completed"
    opts.ttl = 0
    notify(message, vim.log.levels.INFO, opts)
    return
  end

  status.complete = false
  if M.options.notification_delay == 0 then
    status.busy = true
  end

  if status.busy then
    notify(message, vim.log.levels.INFO, opts)
  elseif not status.timer then
    status.timer = vim.uv.new_timer()
    status.timer:start(M.options.notification_delay, 0, function()
      vim.schedule(function()
        stop_timer(status)
        if not status.complete then
          status.busy = true
          notify(status.message, vim.log.levels.INFO, opts)
        end
      end)
    end)
  end
end

require("fidget.options").declare(M, "integration.clangd", M.options, function()
  if not M.options.enable then
    return
  end
  vim.lsp.handlers["textDocument/clangd.fileStatus"] = M.handler
end)

return M
