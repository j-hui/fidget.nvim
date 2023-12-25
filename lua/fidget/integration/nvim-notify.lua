local M = {}

--- Delegate notification to |nvim-notify| (if available).
---
---@param msg   string|nil
---@param level string|number|nil
---@param opts  table|nil
---@return      boolean success
function M.delegate(msg, level, opts)
  return pcall(function() require("notify")(msg, level, opts) end)
end

return M
