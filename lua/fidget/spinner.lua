---@mod fidget.spinner Spinner animations
local spinner    = {}
spinner.patterns = require("fidget.spinner.patterns")

--- A Manga is a table specifying an Anime to generate.
---
--- The period is specified in seconds; if omitted, it defaults to 1.
---
---@alias Manga { pattern: string[]|string, period: number|nil } | { [1]: string[]|string }

--- An Anime is a function that takes a timestamp and renders a frame (string).
---
--- Note that Anime is a subtype of Display.
---@alias Anime fun(now: number): string

--- Generate an Anime function that can be polled for spinner animation frames.
---
--- The period is specified in seconds; if omitted, it defaults to 1.
---
---@param pattern string[]|string Either an array of frames, or the name of a known pattern
---@param period number|nil       How long one cycle of the animation should take, in seconds
---@return Anime anime            Call this function to compute the frame at some timestamp
function spinner.animate(pattern, period)
  period = period or 1
  if type(pattern) == "string" then
    local pattern_name = pattern
    pattern = spinner.patterns[pattern_name]
    assert(pattern ~= nil, "Unknown pattern: " .. pattern_name)
  end

  --- Timestamp of the first frame of the animation.
  ---@type number?
  local origin

  return function(now)
    if not origin then
      origin = now
    end

    -- Compute time modulo period of animation
    now = (now - origin) % period

    return pattern[math.floor((now * #pattern / period) + 1)]
  end
end

return spinner
