--- Declarative options for this plugin (not specific to Fidget).
local M = {}

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
    local warnlog = {}
    opts = opts or {}
    for key, setup in pairs(sub_setup) do
      local subwarnlog = setup(opts[key])
      for _, w in ipairs(subwarnlog) do
        table.insert(warnlog, w)
      end
    end
    for key, val in pairs(opts) do
      if not sub_setup[key] then
        if mod.options[key] == nil then
          table.insert(warnlog, "unknown option: " .. prefix .. tostring(key))
        else
          mod.options[key] = val
        end
      end
    end
    if post_setup then
      post_setup(warnlog)
    end
    return warnlog
  end
end

return M
