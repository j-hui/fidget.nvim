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

  --- Maximum log file size, in KB
  ---
  --- If this option is set to `false`, the log file will be let to grow
  --- indefinitely.
  ---
  --- When the log file exceeds this size, it is backed up with suffix `.bak`,
  --- overwriting any possible previous backup. Thus, the maximum on-disk
  --- footprint of Fidget logs is approximately twice `logger.max_size`.
  --- If you would like to retain the backup log, copy it manually.
  ---
  --- Note that there is a possible race condition when two concurrent Neovim
  --- processes both try to back up the log file. Thus, a fresh backup log file
  --- may be clobbered by a concurrent Neovim process, before you have a chance
  --- to back move it somewhere safe for later inspection. So, when debugging
  --- Fidget, run only one instance of Neovim, or set this option to `false`.
  ---
  ---@type number | false
  max_size = 10000,

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

require("fidget.options").declare(M, "logger", M.options, function()
  -- Create directory where log will reside
  vim.fn.mkdir(vim.fn.fnamemodify(M.options.path, ":p:h"), "p")

  if M.options.max_size then
    -- Simulate opening the log at startup, so that any potential file system
    -- issues arise sooner than later. Also forces log to be created or pruned.
    local log = M.open_log()
    if log then
      log:close()
    else
      vim.notify("Could not open Fidget log: " .. M.options.path, vim.log.levels.WARN)
    end
  end
end)

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

  -- if M.options.max_size then
  --   M.prune_log(false)
  -- end

  local info = debug.getinfo(3, "Sl")
  local _, _, filename = string.find(info.short_src, PLUGIN_PATH_PATTERN)
  local lineinfo = (filename or info.short_src) .. ":" .. info.currentline

  local log = M.open_log()
  if log then
    local log_line = string.format("[%-6s%s] %s: %s\n",
      M.fmt_level(level), os.date(), lineinfo, make_string(...))
    log:write(log_line)
    log:close()
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

--- Open the Fidget log; prune the existing log if it has grown too large.
---
--- Possibly returns an open file handle to the log; it is the caller's
--- responsibility to `:close()` it.
---
---@return file*|nil
function M.open_log()
  local fp = io.open(M.options.path, "a")
  if fp == nil then
    return
  end

  local size = fp:seek("end") / 1024
  if M.options.max_size == false or size < M.options.max_size then
    return fp
  end

  fp:close()
  os.rename(M.options.path, M.options.path .. ".bak")
  return io.open(M.options.path, "a")
end

return M
