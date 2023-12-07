local M = {}

require("fidget.options").declare(M, "integration.nvim-tree", {
  enable = false,
}, function()
  if M.option.enable == true then
    local ntree = require("nvim-tree")
    local win = require("fidget.notification.window")

    ntree.api.events.subscribe(ntree.api.events.TreeOpen, function()
      if win.relative == "editor" then

      end
    end)

    ntree.api.events.subscribe(ntree.api.events.TreeClose, function()
      win.set_x_offset(0)
    end)

    ntree.api.events.subscripe(ntree.api.events.Resize, function(size)

    end)
  end
end)

return M
