local M = {}
local logger = require("fidget.logger")

--- Returns the current high-resolution timestamp (in nanoseconds).
---
---@return number
function M.get_time()
  return vim.uv.hrtime()
end

--- Obtain the (whole) seconds passed since Jan 1, 1970.
---
--- In particular, the result from this function is suitable for consumption by
--- |strftime()|.
---
---@return integer localtime
function M.unix_time()
  return vim.uv.clock_gettime("realtime").sec
end

--- Encapsulates a function that should be called periodically.
---@class Poller
---@field name string
---@field private poll fun(self: Poller): boolean what to do for polling
---@field private timer uv.uv_timer_t? timer handle when this poller is polling
---@field private start_t number start time of the poller
---@field private current_t number time at each poll
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
  if self.timer and self.timer:is_active() or self.err ~= nil then
    return
  end
  if not attack then
    attack = 15
  end
  if poll_rate <= 0 or attack < 0 then
    local err = string.format(
      "Poller ( %s ) could not start due to %s: %d",
      self.name,
      poll_rate <= 0 and "non-positive poll_rate" or "negative attack",
      poll_rate <= 0 and poll_rate or attack
    )
    logger.error(err)
    return
  end
  local interval = math.ceil(1000 / poll_rate)
  local notice = logger.at_level(vim.log.levels.INFO)
  local time = M.get_time

  if not self.timer then
    local err
    self.timer, err = vim.uv.new_timer()
    if not self.timer then
      error(err) -- raise this
    end
    if not self.callback then
      self.callback = function()
        if not self.timer or self.err ~= nil then
          return
        end
        self.current_t = time()

        -- logger.debug(collectgarbage("count"))

        local ok, res = pcall(self.poll, self)
        if not ok or not res then
          self.timer:stop()

          if notice then
            local end_t = time() / 1e9
            -- NOTE: the timing info logged here is not tied to self.current_time
            logger.info(string.format(
              "Poller ( %s ) stopping at %.3fs (duration: %.3fs) due to %s",
              self.name,
              end_t,
              end_t - self.start_t,
              ok and "completion" or "error"
            ))
          end
          if not ok then
            self.err = res
            logger.error(res)
          end
        end
      end
    end
  end
  if notice then
    self.start_t = time() / 1e9
    logger.info(string.format("Poller ( %s ) starting at %.3f", self.name, self.start_t))
  end
  self.timer:start(attack, interval, function() vim.schedule(self.callback) end)
end

--- Call the poll() function once, if the poller isn't already running.
function Poller:poll_once()
  if self.timer then
    return
  end

  vim.schedule(function()
    self.current_t = M.get_time()
    if logger.at_level(vim.log.levels.INFO) then
      logger.info("Poller (", self.name, ") polling once at", string.format("%.3fs", self.current_t))
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
  return self.current_t
end

--- Whether a poller is actively polling.
---
---@return boolean? is_polling
function Poller:is_polling()
  return self.timer and self.timer:is_active()
end

--- Query poller for potential encountered error.
---
---@return any? error_object
function Poller:has_error()
  return self.err
end

--- Release timer resources
function Poller:release()
  if self.timer then
    if self.timer:is_active() then
      self.timer:stop()
    end
    self.timer:close()
    self.timer = nil
  end
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
    name      = name,
    poll      = opts.poll or function() return false end,
    timer     = nil,
    start_t   = 0, -- log metric
    current_t = 0, -- frame time
    err       = nil,
  }
  return setmetatable(poller, Poller)
end

return M
