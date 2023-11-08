--- Adapted from https://www.github.com/tjdevries/vlog.nvim
local M = {}

require("fidget.options")(M, {
  --- Minimum log level; set to vim.log.levels.OFF to disable logging
  level = vim.log.levels.DEBUG,

  --- Limit the number of decimals displayed for floats
  float_precision = 0.01,
})

local PLUGIN_NAME = "fidget.nvim"
local PLUGIN_PATH_PATTERN = "(/lua/fidget.+)"

local log_file = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "data" }), PLUGIN_NAME)

local function fmt_level(level)
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

  local fp = io.open(log_file, "a")
  if fp then
    local log_line = string.format("[%-6s%s] %s: %s\n",
      fmt_level(level), os.date(), lineinfo, make_string(...))
    fp:write(log_line)
    fp:close()
  end
end

function M.log(level, ...)
  do_log(level, ...)
end

function M.debug(...)
  do_log(vim.log.levels.DEBUG, ...)
end

function M.info(...)
  do_log(vim.log.levels.INFO, ...)
end

function M.warn(...)
  do_log(vim.log.levels.WARN, ...)
end

function M.error(...)
  do_log(vim.log.levels.ERROR, ...)
end

return M
