local M = {}
local logger = require("fidget.logger")

--- Arbitrary point in time that timestamps are computed relative to.
---
--- Units are in seconds. `unix_time` is relative to Jan 1 1970, while
--- `origin_time` is relative to some arbitrary system-specific time.
---
--- This module captures both at the time so that we can freely convert between
--- the two. By default, we use `origin_time` / `reltime()` since these offer
--- higher precision, but then we use `unix_time` to normalize it to something
--- human-readable.
---
---@type number, number
local unix_time, origin_time = vim.fn.localtime(), vim.fn.reltime()

--- Obtain the seconds passed since this module was initialized.
---
---@return number
function M.get_time()
  return vim.fn.reltimefloat(vim.fn.reltime(origin_time))
end

--- Obtain the (whole) seconds passed since Jan 1, 1970.
---
--- In particular, the result from this function is suitable for consumption by
--- |strftime()|.
---
---@param reltime number|nil
---@return number localtime
function M.unix_time(reltime)
  reltime = reltime or M.get_time()
  return math.floor(unix_time + reltime)
end

---luv uv_timer_t handle
---@class uv_timer_t
---@field start fun(self: self, atk: number, delay: number, fn: function)
---@field stop fun(self: self)
---@field close fun(self: self)

--- Encapsulates a function that should be called periodically.
---@class Poller
---@field name string
---@field private poll fun(self: Poller): boolean what to do for polling
---@field private timer uv_timer_t? timer handle when this poller is polling
---@field private current_time number time at each poll
---@field private err any? error object possibly encountered while polling
---
--- Note that when the Poller:poll() method returns true, the poller should
--- call it again, but if it returns anything false-y, the poller will stop.
---
--- If a poller encounters an error while polling, it will refuse to start
--- polling again until its err is reset.
local Poller = {}
Poller.__index = Poller

--- Start polling the poll() function at the given poll_rate.
---
--- Only does so after waiting for attack milliseconds; if no attack is
--- specified, it defaults to 15ms.
---
---@param poll_rate number    must be greater than 0
---@param attack    number?   must be greater than or equal to 0
function Poller:start_polling(poll_rate, attack)
  if self.timer then
    return
  end

  attack = attack or 15

  if poll_rate <= 0 then
    local msg = string.format("Poller ( %s ) could not start due to non-positive poll_rate: %s", self.name, poll_rate)
    logger.error(msg)
    error(msg)
  end

  if attack < 0 then
    local msg = string.format("Poller ( %s ) could not start due to negative poll_rate: %s", self.name, poll_rate)
    logger.error(msg)
    error(msg)
  end

  self.timer = vim.loop.new_timer()

  local start_time

  if logger.at_level(vim.log.levels.INFO) then
    start_time = M.get_time()
    logger.info("Poller (", self.name, ") starting at", string.format("%.3fs", start_time))
  end

  self.timer:start(attack, math.ceil(1000 / poll_rate), vim.schedule_wrap(function()
    if not self.timer or self.err ~= nil then
      return
    end

    self.current_time = M.get_time()

    local ok, cont = pcall(self.poll, self)

    if not ok or not cont then
      self.timer:stop()
      self.timer:close()
      self.timer = nil

      if logger.at_level(vim.log.levels.INFO) then
        -- NOTE: the timing info logged here is not tied to self.current_time
        local end_time = M.get_time()
        local duration = end_time - (start_time or math.huge)
        local message = string.format("stopping at %.3fs (duration: %.3fs)", end_time, duration)
        local reason = ok and "due to completion" or string.format("due to error: %s", tostring(cont))
        logger.info("Poller (", self.name, ")", message, reason)
      end

      if not ok then
        -- Save error object and propagate it
        self.err = cont
        error(cont)
      end
    end
  end))
end

--- Call the poll() function once, if the poller isn't already running.
function Poller:poll_once()
  if self.timer then
    return
  end

  vim.schedule(function()
    self.current_time = M.get_time()
    if logger.at_level(vim.log.levels.INFO) then
      logger.info("Poller (", self.name, ") polling once at", string.format("%.3fs", self.current_time))
    end
    local ok, err = pcall(self.poll, self)
    if not ok then
      self.err = err
      error(err)
    end
  end)
end

--- Get the timestamp of the most recent poll frame.
---
--- Useful within a poll frame to provide a synchronous view of the world.
---
---@return number
function Poller:now()
  return self.current_time
end

--- Whether a poller is actively polling.
---
---@return boolean is_polling
function Poller:is_polling()
  return self.timer ~= nil
end

--- Query poller for potential encountered error.
---
---@return any? error_object
function Poller:has_error()
  return self.err
end

--- Forget about error object so that poller can start polling again.
function Poller:reset_error()
  self.err = nil
end

--- Construct a Poller object.
---@param opts { name: string?, poll: fun(self: Poller): boolean }?
---@return Poller poller
function M.Poller(opts)
  opts = opts or {}

  local name = opts.name
  if not name then
    -- Use debug info to construct name
    local info = debug.getinfo(2, "Sl")
    local _, _, filename = string.find(info.short_src, "(/lua/fidget.+)")
    local lineinfo = (filename or info.short_src) .. ":" .. info.currentline
    name = lineinfo
  end

  ---@type Poller
  local poller = {
    name         = name,
    poll         = opts.poll or function() return false end,
    timer        = nil,
    current_time = 0,
    err          = nil,
  }
  return setmetatable(poller, Poller)
end

return M
