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

local last_step = 0 -- 0: just created, 1: shown, 2: completed
local notify = require"fidget.notification".notify
local timer = nil
local function stop_timer()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

M.handler = function(err, result, ctx, config)
  if not result.state then return end
  stop_timer()

  local message = result.state
  local opts = {
    key = "clangd.fileStatus",
    group = ctx.client_id,
    annote = M.options.annote,
    ttl = math.huge,
  }

  if message == "idle" then
    if last_step ~= 1 then
      -- no notification displayed
      last_step = 2
      return
    end
    -- update notification
    last_step = 2
    message = "Completed"
    opts.ttl = 0
    notify(message, vim.log.levels.INFO, opts)
    return
  end

  last_step = 0

  if M.options.notification_delay == 0 then
    last_step = 1
    notify(message, vim.log.levels.INFO, opts)
    return
  end

  timer = vim.uv.new_timer()
  timer:start(M.options.notification_delay, 0, function()
    stop_timer()
    vim.schedule(function()
      if last_step == 0 then
        last_step = 1
        notify(message, vim.log.levels.INFO, opts)
      end
    end)
  end)
end

require("fidget.options").declare(M, "integration.clangd", M.options, function()
  if not M.options.enable then
    return
  end
    vim.lsp.handlers["textDocument/clangd.fileStatus"] = M.handler
end)

return M
