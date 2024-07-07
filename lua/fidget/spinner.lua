---@mod fidget.spinner Spinner animations
local M      = {}
M.patterns   = require("fidget.spinner.patterns")
local logger = require("fidget.logger")

--- The frames of an animation.
---
--- Either an array of strings, which comprise each frame of the animation,
--- or a string referring to the name of a built-in pattern. Note that this
--- means `{ "dots" }` is different from `"dots"`; the former is a static
--- animation, consisting of a single frame, `dots`, while the latter refers to
--- the built-in pattern named "dots".
---
--- Specifying built-in patterns by name like this is DEPRECATED and will be
--- removed in a future release; instead of `"dots"`, directly import the
--- pattern using `require("fidget.spinner.patterns").dots`.
---
--- The array must contain at least one frame.
---
---@alias Frames string[]|string

--- A Manga is a table specifying an Anime to generate.
---
--- When the pattern is omitted, it will be looked up from the first position
--- instead, i.e., from key `[1]`. That means writing `{ the_pattern }` is
--- equivalent to `{ pattern = the_pattern }`. However, this behavior is
--- DEPRECATED and will be removed in a future release; prefer using using the
--- explicit `pattern` key.
---
--- The period is specified in seconds; if omitted, it defaults to 1.
---
---@alias Manga { pattern: Frames, period: number|nil, [1]: Frames|nil }

--- An Anime is a function that takes a timestamp and renders a frame (string).
---
--- Note that Anime is a subtype of Display.
---@alias Anime fun(now: number): string

--- A basic Anime function used to indicate an error.
---
--- Returned by `spinner.animate()` when there is an error, to ensure that
--- Fidget will work even with a semi-broken config.
---
--- An Anime original, if you will.
---
---@type Anime
function M.bad(now)
  if math.floor(now) % 2 == 0 then
    return " BAD_PATTERN "
  else
    return "             "
  end
end

--- Generate an Anime function that can be polled for spinner animation frames.
---
--- The period is specified in seconds; if omitted, it defaults to 1.
---
---@param manga Manga             A Manga from which to generate an Anime
---@return Anime|string anime     Get the frame at some timestamp, or a single static frame
function M.animate(manga)
  local pattern = manga.pattern

  if pattern == nil then
    logger.warn("Specifying the pattern like `{ pat }` is DEPRECATED; use `{ patter = pat }` instead.")
    pattern = manga[1]
  end

  if pattern == nil then
    logger.error("No pattern specified")
    return M.bad
  end

  if type(pattern) == "string" then
    logger.warn("Specifying a built-in pattern by name is DEPRECATED; import it from `fidget.spinner.patterns`.")

    local pattern_name = pattern
    pattern = M.patterns[pattern_name]

    if pattern == nil then
      logger.error("Unknown pattern:", pattern_name)
      return M.bad
    end
  end

  if type(pattern) ~= "table" or #pattern < 1 then
    logger.error("Invalid pattern:", pattern)
    return M.bad
  end

  if #pattern == 1 then
    logger.info("Animating single-frame pattern:", pattern[1])
    return pattern[1]
  end

  local period = manga.period or 1

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

return M
