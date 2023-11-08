--- Declare a table of available options for a module, which can be accessed via
--- MOD.options. Also creates a MOD.setup(opts) which merges the given opts with
--- the current options.
---
--- Supports "submodules", i.e., redirects certain keys to the options of
--- another module, e.g.:
---
---     options = require("fidget.options")
---
---     local sub_module = {}
---     local function post_setup()
---       sub_module.post_bar = sub_module.options.bar * 2
---     end
---
---     options(sub_module, {
---       foo = true,
---       bar = 0,
---     }, post_setup)
---
---     ...
---
---     local module = {}
---     options(module, {
---       baz = "baz",
---       sub_module = sub_module,
---     })
---
---     ...
---
---     module.setup {
---       baz = "bazn't",
---       sub_module = {
---         bar = 42
---       },
---     }
---
---     assert(module.options.baz == "bazn't")
---     assert(module.options.sub_module.foo == true)
---     assert(sub_module.options.bar == 42)
---     assert(sub_module.post_bar == 42 * 2)
---
---@param mod           table     the module to which options are being attached
---@param default_opts  table     the default set of options
---@param post_setup    function? called after setup() is called
local function declare_options(mod, default_opts, post_setup)
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

  set_fidget_module(mod)

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
        mod.options[key] = val
      end
    end
    if post_setup then
      post_setup()
    end
  end
end

return declare_options
