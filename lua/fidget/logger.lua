--- Adapted from https://www.github.com/tjdevries/vlog.nvim
local M = {}

local PLUGIN_PATH_PATTERN = "(/lua/fidget.+)"

---@options logger [[
---@protected
--- Logging options
M.options = {
  --- Minimum logging level
  ---
  --- Set to `vim.log.levels.OFF` to disable logging, or `vim.log.levels.TRACE`
  --- to enable all logging.
  ---
  --- Note that this option only filters logging (useful for debugging), and is
  --- different from `notification.filter`, which filters `notify()` messages.
  ---
  ---@type 0|1|2|3|4|5
  level = vim.log.levels.WARN,

  --- Limit the number of decimals displayed for floats
  ---
  ---@type number
  float_precision = 0.01,

  --- Where Fidget writes its logs to
  ---
  --- Using `vim.fn.stdpath("cache")`, the default path usually ends up at
  --- `~/.cache/nvim/fidget.nvim.log`.
  ---
  ---@type string
  path = string.format("%s/fidget.nvim.log", vim.fn.stdpath("cache")),
}
---@options ]]

require("fidget.options").declare(M, "logger", M.options)

function M.fmt_level(level)
  if level == vim.log.levels.DEBUG then
    return "DEBUG"
  elseif level == vim.log.levels.INFO then
    return "INFO"
  elseif level == vim.log.levels.WARN then
    return "WARN"
  elseif level == vim.log.levels.ERROR then
    return "ERROR"
  else
    return "UNKNOWN"
  end
end

local function round(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end

local function make_string(...)
  local t = {}
  for i = 1, select("#", ...) do
    local x = select(i, ...)

    if type(x) == "number" and M.options.float_precision then
      x = tostring(round(x, M.options.float_precision))
    elseif type(x) == "table" then
      x = vim.inspect(x)
    else
      x = tostring(x)
    end

    t[#t + 1] = x
  end
  return table.concat(t, " ")
end

local function do_log(level, ...)
  if level < M.options.level then
    return
  end
  local info = debug.getinfo(3, "Sl")
  local _, _, filename = string.find(info.short_src, PLUGIN_PATH_PATTERN)
  local lineinfo = (filename or info.short_src) .. ":" .. info.currentline

  local fp = io.open(M.options.path, "a")
  if fp then
    local log_line = string.format("[%-6s%s] %s: %s\n",
      M.fmt_level(level), os.date(), lineinfo, make_string(...))
    fp:write(log_line)
    fp:close()
  end
end

--- Log at the specified level.
function M.log(level, ...)
  do_log(level, ...)
end

--- Log a message at the DEBUG level.
function M.debug(...)
  do_log(vim.log.levels.DEBUG, ...)
end

--- Log a message at the INFO level.
function M.info(...)
  do_log(vim.log.levels.INFO, ...)
end

--- Log a message at the WARN level.
function M.warn(...)
  do_log(vim.log.levels.WARN, ...)
end

--- Log a message at the ERROR level.
function M.error(...)
  do_log(vim.log.levels.ERROR, ...)
end

--- Whether a logging level is enabled.
---
--- Useful for guarding against computing log output that is thrown away.
---
---@param level 0|1|2|3|4|5
---@return boolean at_level
function M.at_level(level)
  return level >= M.options.level
end

return M
