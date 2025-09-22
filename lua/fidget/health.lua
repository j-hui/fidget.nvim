local M = {}

local bug_advice = "This is probably a bug. Please open an issue on https://github.com/j-hui/fidget.nvim."

local function info(msg)
  vim.health.info("ℹ️ INFO " .. msg)
end

local unknown_options = {}
local deprecated_options = {}

function M.log_unknown_option(key)
  unknown_options[key] = true
end

function M.log_deprecated_option(key, advice)
  deprecated_options[key] = advice
end

local function check_options()
  vim.health.start("fidget.setup")
  local options_ok = true

  for opt, _ in pairs(unknown_options) do
    options_ok = false
    vim.health.warn("Unknown setup option: '" .. opt .. "'")
  end

  for opt, advice in pairs(deprecated_options) do
    options_ok = false
    if type(advice) == "string" then
      vim.health.warn("Deprecated setup option: '" .. opt .. "'", advice)
    else
      vim.health.warn("Deprecated setup option: '" .. opt .. "'")
    end
  end

  if options_ok then
    vim.health.ok("All user-specified options are known and accounted for")
  end
end

local function check_integrations()
  vim.health.start("fidget.integration")

  local xcodebuild = require("fidget.integration.xcodebuild-nvim")
  if not xcodebuild.explicitly_configured() and xcodebuild.plugin_present() then
    vim.health.warn("xcodebuild.nvim integration is implicitly enabled", {
      "This automatic integration will be removed in a future release.",
      "Add 'TestExplorer' to the 'notification.window.avoid' list to ensure Fidget continues to avoid xcodebuild.nvim's explorer window.",
    })
  end

  local nvim_tree = require("fidget.integration.nvim-tree")
  if not nvim_tree.explicitly_configured() and nvim_tree.plugin_present() then
    vim.health.warn("nvim-tree.lua integration is implicitly enabled", {
      "This automatic integration will be removed in a future release.",
      "Add 'NvimTree' to the 'notification.window.avoid' list to ensure Fidget continues to avoid nvim-tree.lua's file explorer.",
    })
  end
end

local function check_progress()
  vim.health.start("fidget.progress")
  local progress = require("fidget.progress")

  if vim.lsp.status then
    vim.health.ok("Using LspProgress handler implementation")
  else
    vim.health.warn("Using legacy LspProgressUpdate handler implementation", {
      "This should only be used for Neovim v0.8.0--v0.9.4.",
      "Consider upgrading to the latest version of Neovim.",
    })
  end

  local ringbuf_size = progress.lsp.options.progress_ringbuf_size
  if ringbuf_size and ringbuf_size > 0 then
    local prefix = "Option 'progress.lsp.progress_ringbuf_size' is set "
    if not vim.ringbuf then
      vim.health.warn(prefix .. "but 'vim.ringbuf' is unavailable", {
        "This option does nothing for Neovim pre-v0.10.0.",
        "Consider upgrading to the latest version of Neovim.",
      })
    elseif progress.lsp.lsp_attach_autocmd then
      vim.health.ok(prefix .. "to " .. tostring(ringbuf_size))
    else
      vim.health.error(prefix .. "but LspAttach autocmd not installed", bug_advice)
    end
  else
    vim.health.ok("Option 'progress.lsp.progress_ringbuf_size' is 0, using default size")
  end

  if progress.lsp.options.log_handler then
    vim.health.warn([['vim.lsp.handlers["$/progress"]' is overridden with Fidget logger]], {
      "Setting the 'progress.lsp' option is not recommended.",
      "This option exists primarily for debugging.",
    })
  end
end

local function check_notification()
  vim.health.start("fidget.notification")
  local notification = require("fidget.notification")

  if vim.notify == notification.notify then
    vim.health.ok("vim.notify() is set to fidget.notify()")
  elseif notification.options.override_vim_notify then
    vim.health.error("'override_vim_notify' is true, but vim.notify() is not set to fidget.notify()", {
      "vim.notify() might be overwritten elsewhere in your config.",
    })
  else
    info("vim.notify() is not set to fidget.notify()")
  end

  if notification.view.check_multigrid_ui() then
    info("Rendering notifications for multigrid UI (e.g., neovide)")
  else
    info("Rendering notifications for regular UI (e.g., nvim TUI)")
  end
end

function M.check()
  check_options()
  check_integrations()
  check_progress()
  check_notification()
end

return M
