local M = {}

-- Only register one callback, so setup() can be called multiple times.
local already_subscribed = false

---@options integration.nvim-tree [[
--- nvim-tree integration
M.options = {
  --- Integrate with nvim-tree/nvim-tree.lua (if installed)
  ---
  --- Dynamically offset Fidget's notifications window when the nvim-tree window
  --- is open on the right side + the Fidget window is "editor"-relative.
  ---
  ---@type boolean
  enable = true,
}
---@options ]]

require("fidget.options").declare(M, "integration.nvim-tree", M.options, function()
  if not M.options.enable or already_subscribed then
    return
  end

  local ok, api = pcall(function() return require("nvim-tree.api") end)
  if not ok or not api.tree.winid then
    -- NOTE: api.tree.winid doesn't exist on some older versions of nvim-tree.
    -- We need it to figure out the size of the nvim-tree window, so if it does
    -- not exist, there's no point in installing any nvim-tree event callbacks.
    return
  end

  already_subscribed = true

  local win = require("fidget.notification.window")

  local function resize()
    if win.options.relative == "editor" then
      local winid = api.tree.winid()
      local col = vim.api.nvim_win_get_position(winid)[2]
      if col > 1 then
        local width = vim.api.nvim_win_get_width(winid)
        win.set_x_offset(width + 1)
      end
    end
  end

  local function reset()
    win.set_x_offset(0)
  end

  api.events.subscribe(api.events.Event.TreeOpen, resize)
  api.events.subscribe(api.events.Event.Resize, resize)
  api.events.subscribe(api.events.Event.TreeClose, reset)
end)

return M
