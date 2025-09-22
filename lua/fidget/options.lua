--- Declarative options for this plugin (not specific to Fidget).
local M = {}
local health = require("fidget.health")

---@class fidget.DeprecatedOption<T> : { default_value: T, deprecated_option: string|true }

---@generic T
---@param default_value T
---@param advice string|nil
---@return fidget.DeprecatedOption<T>
function M.deprecated(default_value, advice)
  return {
    default_value = default_value,
    deprecated_option = advice or true,
  }
end

--- Declare a table as a fidget module, so we can tell using is_fidget_module().
local function set_fidget_module(m)
  local mt = getmetatable(m)
  if not mt then
    mt = {}
    setmetatable(m, mt)
  end
  mt.fidget_module = true
end

--- Whether this is fidget module, i.e., set_fidget_module() was called on it.
local function is_fidget_module(m)
  if type(m) ~= "table" then
    return false
  end
  local mt = getmetatable(m)
  return mt and mt.fidget_module == true
end

--- Declare a table of available options for a module M. For internal use.
---
--- Those options can be accessed via M.options.
---
--- Also creates M.setup(opts) to merge the given opts with current options.
---
--- Supports "submodules", i.e., redirects certain keys to the options of
--- another module, e.g.:
---
---     options = require("fidget.options")
---
---     local SM = {}
---     local function post_setup()
---       SM.post_bar = SM.options.bar * 2
---     end
---
---     SM.options = {
---       foo = true,
---       bar = 0,
---     }
---     options.declare(SM, SM.options, post_setup)
---
---     ...
---
---     local M = {}
---     M.options = {
---       baz = "baz",
---       sub_module = SM,
---     }
---     options.declare(M, M.options)
---
---     ...
---
---     M.setup {
---       baz = "bazn't",
---       sub_module = {
---         bar = 42
---       },
---     }
---
---     assert(M.options.baz == "bazn't")
---     assert(M.options.sub_module.foo == true)
---     assert(SM.options.bar == 42)
---     assert(SM.post_bar == 42 * 2)
---
--- Designed this way to keep the configuration structure sane and close to the
--- implementation structure (which we assume to be sane xD).
---
---@param mod           table     the module to which options are being attached
---@param name          string    name of the module
---@param default_opts  table     the default set of options
---@param post_setup    function? called after setup() is called
function M.declare(mod, name, default_opts, post_setup)
  set_fidget_module(mod)

  local prefix = name == "" and "" or (name .. ".")

  local options, sub_setup = {}, {}
  for k, v in pairs(default_opts) do
    if is_fidget_module(v) then
      sub_setup[k] = v.setup
      options[k] = v.options
    else
      options[k] = v
    end
  end

  mod.options = options

  ---@param opts table? table of options passed to setup function
  mod.setup = function(opts)
    opts = opts or {}
    for key, setup in pairs(sub_setup) do
      setup(opts[key])
    end
    for key, val in pairs(opts) do
      if not sub_setup[key] then
        if mod.options[key] == nil then
          health.log_unknown_option(prefix .. tostring(key))
        else
          if type(mod.options[key]) == "table" and mod.options[key].deprecated_option then
            health.log_deprecated_option(prefix .. tostring(key), mod.options[key].deprecated_option)
          end
          mod.options[key] = val
        end
      end
    end
    if post_setup then
      post_setup()
    end
  end
end

return M
