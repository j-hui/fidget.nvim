--- `:Fidget` and its subcommands
local SC = {}

--- The specification of a subcommand.
---@class SubCommand
---@field desc string                     Human-readable description of the subcommand
---@field args table<string|number, Arg>  Specification of named and positional arguments
---@field func fun(table)                 Subcommand callback

--- The specification of a subcommand argument.
---@class Arg
---@field name string|nil     Human-readable name of the argument (optional for named arguments)
---@field desc string         Human-readable description of the argument
---@field type Type           Type of the argument

--- The specification of an argument type.
---@class Type
---@field name string                                   Human-readable name of the type
---@field parse fun(str: string): (any|nil)             How to parse the argument (returns nil if it cannot be parsed)
---@field suggestions string[]|(fun(): string[])|nil    Possible list of completion suggestions
---@field override fun(self, tbl: table): Type          Create a new Type with the given fields overridden

---@param typ table
---@return Type typ
function SC.Type(typ)
  local mt = getmetatable(typ) or {}
  mt.__index = mt.__index or {}
  mt.__index.override = function(self, tbl)
    return SC.Type(vim.tbl_extend("force", self, tbl))
  end
  setmetatable(typ, mt)
  return typ
end

---@type Type
SC.Boolean = SC.Type {
  name = "boolean",
  suggestions = { "true", "false" },
  parse = function(str)
    if str == "true" then
      return true
    elseif str == "false" then
      return false
    else
      return nil
    end
  end
}

---@type Type
SC.Number = SC.Type {
  name = "number",
  parse = tonumber,
}

---@type Type
SC.String = SC.Type {
  name = "string",
  parse = function(str)
    if string.sub(str, 1, 1) == [["]] and string.sub(str, #str) == [["]] then
      str = string.sub(str, 2, #str - 1)
      return string.find(str, [["]]) == nil and str or nil
    elseif string.sub(str, 1, 1) == [[']] and string.sub(str, #str) == [[']] then
      str = string.sub(str, 2, #str - 1)
      return string.find(str, [[']]) == nil and str or nil
    else
      return string.find(str, [["']]) == nil and str or nil
    end
  end
}

---@param alts string[]
---@return Type
function SC.Enum(alts)
  return SC.Type {
    name = [["]] .. table.concat(alts, [["|"]]) .. [["]],
    suggestions = alts,
    parse = function(str)
      for _, alt in ipairs(alts) do
        if str == alt then
          return str
        end
      end
      return nil
    end,
  }
end

---@type Type
SC.Any = SC.Type {
  name = "any",
  parse = function(str)
    local v = SC.Boolean.parse(str)
    if v ~= nil then return v end
    v = SC.Number.parse(str)
    if v ~= nil then return v end
    v = SC.String.parse(str)
    if v ~= nil then return v end
    return nil
  end,
}

--- Return the name of a potential flag, or nil if not a flag
---
---@param str string
---@return string|nil flag
function SC.parse_flag(str)
  if string.sub(str, 1, 2) == "--" then
    local flag = string.gsub(string.sub(str, 3), "-", "_")
    return flag
  else
    return nil
  end
end

--- Break a string down into space-separated chunks
---
--- Space separation is disabled when using quotes. The following string:
---
--- ```
--- This "is a" 'collection' of chunks, "isn't" 'this "neat'? "XD
--- ```
---
--- is tokenized into the following array:
---
--- ```
--- { [[This]], [["is a"]] [['collection']], [[of]], [[chunks]], [["isn't"]], [['this "neat']], [["XD]] }
--- ```
---
---@param str string
---@return    string[] tokens
function SC.tokenize(str)
  local tokens = {}

  ---@type "\""|"'"|nil
  local quote = nil

  for s in string.gmatch(str, [[.-%S+]]) do
    if quote ~= nil then
      tokens[#tokens] = tokens[#tokens] .. s
    else
      table.insert(tokens, string.match(s, [[(%S+)]]))
    end

    for q in string.gmatch(s, [[(['"])]]) do
      if quote == nil then
        quote = q
      elseif quote == q then
        quote = nil
      end
    end
  end
  return tokens
end

--- Sort a table by its key, returning a sorted associative list, i.e., [(Key, Value)].
---
---@generic K
---@generic V
---@param tbl table<K, V>
---@return    { [1]: K, [2]: V}[] sorted
local function sort_by_key(tbl)
  local sorted = {}
  for k, v in pairs(tbl) do
    table.insert(sorted, { k, v })
  end
  table.sort(sorted, function(a, b) return tostring(a[1]) < tostring(b[1]) end)
  return sorted
end

--- Generate command handler function from subcommands specification.
---
---@param cmd_name string
---@param subcmds table<string, SubCommand>
---@return fun(table)
function SC.handle_cmd(cmd_name, subcmds)
  return function(cmd)
    --- Helper function for reporting errors
    ---@return nil
    local function throw_error(...)
      vim.notify(string.format(...), vim.log.levels.ERROR)
      return nil
    end

    local chunks = SC.tokenize(cmd.args)

    if not chunks[1] then
      -- Vim already enforces that an argument is required, so if we could not
      -- tokenize, then there must be something seriously wrong.
      return throw_error("Could not parse :%s arguments: `%s'", cmd_name, cmd.args)
    end

    local subcmd = subcmds[chunks[1]]

    if not subcmd then
      return throw_error("Unknown :%s subcommand: `%s'", cmd_name, chunks[1])
    end

    ---@type string|nil, number, table
    local last_flag, cur_pos, args = nil, 1, {}

    for i = 2, #chunks do
      local flag = SC.parse_flag(chunks[i])
      if flag then
        if not subcmd.args[flag] then
          return throw_error("Unknown flag for :%s %s: --%s", cmd_name, chunks[1], flag)
        end
        last_flag = flag
      else
        if last_flag then
          local val = subcmd.args[last_flag].type.parse(chunks[i])
          if val == nil then
            return throw_error("Could not parse flag argument --%s: `%s'", last_flag, chunks[i])
          end
          args[last_flag] = val
          last_flag = nil
        else
          if not subcmd.args[cur_pos] then
            return throw_error("Positional argument out of bounds: `%s'", chunks[i])
          end
          local val = subcmd.args[cur_pos].type.parse(chunks[i])
          if val == nil then
            return throw_error("Could not parse positional argument %s: `%s'", subcmd.args[cur_pos].name, chunks[i])
          end
          args[cur_pos] = val
          cur_pos = cur_pos + 1
        end
      end
    end

    subcmd.func(args)
  end
end

--- Generate completion handler function from subcommands specification.
---
---@param subcmds table<string, SubCommand>
---@return fun(arglead: string, cmdline: string, cursorpos: number): (string[]|nil)
function SC.handle_complete(subcmds)
  return function(_, line, cursorpos)
    line = string.sub(line, 1, cursorpos) -- Strip trailing part of line

    local trailing_whitespace = string.match(string.sub(line, #line), "(%s)") ~= nil
    local chunks = SC.tokenize(line)

    if #chunks < 1 then
      -- Shouldn't be reachable (and we cannot handle completions like this)
      require("fidget.logger").warn("could not tokenize line: `", line, "'")
      return
    end

    if (#chunks == 1 and trailing_whitespace)
        or (#chunks == 2 and not trailing_whitespace)
    then -- e.g., `:Cmd |` or `:Cmd cl|`
      local commands = vim.tbl_keys(subcmds)
      table.sort(commands)
      if chunks[2] then
        return vim.tbl_filter(function(val)
          return vim.startswith(val, chunks[2])
        end, commands)
      else
        return commands
      end
    end

    local subcmd = subcmds[chunks[2] or false]
    if subcmd == nil then
      return nil
    end

    ---@type string|nil, number, number
    local last_flag, cur_pos, limit = nil, 1, #chunks
    if not trailing_whitespace then
      limit = limit - 1
    end

    -- "Fast-forward" through existing args
    for i = 3, limit do
      local flag = SC.parse_flag(chunks[i])
      if flag then
        last_flag = flag
      else
        if last_flag then
          last_flag = nil
        else
          cur_pos = cur_pos + 1
        end
      end
    end

    local suggestions

    if last_flag then
      -- Currently after a flag
      local arg = subcmd.args[last_flag]
      suggestions = arg and arg.type.suggestions
      if type(suggestions) == "function" then
        suggestions = suggestions()
      end
    else
      -- Currently about to type a flag, or a positional arg
      local arg = subcmd.args[cur_pos]
      suggestions = arg and arg.type.suggestions or {}
      if type(suggestions) == "function" then
        suggestions = suggestions()
      end
      for flag in pairs(subcmd.args) do
        if type(flag) == "string" then
          table.insert(suggestions, "--" .. flag)
        end
      end
    end

    if suggestions and #suggestions > 0 then
      if trailing_whitespace then
        return suggestions
      else
        return vim.tbl_filter(function(val)
          return vim.startswith(val, chunks[#chunks])
        end, suggestions)
      end
    else
      return nil
    end
  end
end

--- Generate vim `:help` docs, with the given tag prefix.
---
---@param cmdname string
---@param subname string
---@param subcmd SubCommand
---@param tag_prefix string
---@return string
function SC.vimdoc(cmdname, subname, subcmd, tag_prefix)
  local tag = string.format("*%s-:%s-%s*", tag_prefix, cmdname, subname)
  local cmd = string.format(":%s %s", cmdname, subname)
  local header = string.format("%s%s%s", cmd, string.rep(" ", math.max(78 - #tag - #cmd, 0)), tag)

  local pos_args, named_args = {}, {}
  for _, kv in ipairs(sort_by_key(subcmd.args)) do
    local name, arg = kv[1], kv[2]
    if type(name) == "string" then
      name = string.format("--%s {%s}", name, arg.name or name)
      table.insert(named_args,
        string.format("        %-30s %-12s %s", name, string.format("(%s)", arg.type.name), arg.desc))
    else
      name = string.format("{%s}", arg.name)
      table.insert(pos_args,
        string.format("        %-30s %-12s %s", name, string.format("(%s)", arg.type.name), arg.desc))
    end
  end

  local pos_docs, named_docs = "", ""
  if #named_args > 0 then
    named_docs = string.format([[

    Flags: ~
%s
]], table.concat(named_args, "\n"))
  end
  if #pos_args > 0 then
    pos_docs = string.format([[

    Positional arguments: ~
%s
]], table.concat(pos_args, "\n"))
  end

  return string.format([[
%s

    %s
%s%s]], header, subcmd.desc, named_docs, pos_docs)
end

--- Generate subcommand docs, at the given header level.
---
---@param cmdname string
---@param subname string
---@param subcmd SubCommand
---@param level number|nil
---@return string
function SC.mddoc(cmdname, subname, subcmd, level)
  level = level or 4

  local heading = string.format("%s `:%s %s`", string.rep("#", level), cmdname, subname)

  local pos_args, named_args = {}, {}
  for _, kv in ipairs(sort_by_key(subcmd.args)) do
    local name, arg = kv[1], kv[2]
    if type(name) == "string" then
      table.insert(named_args,
        string.format("-   **`--%s {%s}`**: _`(%s)`_ %s", name, arg.name or name, arg.type.name, arg.desc))
    else
      table.insert(pos_args, string.format("-   **`{%s}`**: _`(%s)`_ %s", arg.name, arg.type.name, arg.desc))
    end
  end

  local pos_docs, named_docs = "", ""
  if #named_args > 0 then
    named_docs = string.format([[

Flags:

%s
]], table.concat(named_args, "\n"))
  end
  if #pos_args > 0 then
    pos_docs = string.format([[

Positional arguments:

%s
]], table.concat(pos_args, "\n"))
  end

  local detailed_docs = ""
  if #named_args > 0 or #pos_args > 0 then
    detailed_docs = string.format([[

<details>
  <summary><i>Arguments</i></summary>
%s%s
</details>]], named_docs, pos_docs)
  end

  return string.format([[%s

%s
%s
]], heading, subcmd.desc, detailed_docs)
end

--[[
================
Everything below this is Fidget-specific (and everything above this isn't)
================
--]]

local COMMAND_NAME = "Fidget"
local COMMAND_DESC = "Fidget ex-mode command interface"

local GroupKey = SC.Any:override {
  suggestions = function()
    return vim.tbl_filter(function(key)
      return type(key) == "string"
    end, require("fidget.notification").group_keys())
  end,
}

---@type table<string, SubCommand>
SC.subcommands = {
  clear = {
    desc = "Clear active notifications",
    func = function(args)
      require("fidget.notification").clear(args[1])
    end,
    args = {
      { name = "group_key", type = GroupKey, desc = "group to clear" },
    },
  },
  history = {
    desc = "Show notifications history",
    func = function(args)
      args.group_key = args[1] or args.group_key
      require("fidget.notification").show_history(args)
    end,
    args = {
      { name = "group_key", type = GroupKey, desc = "filter history by group key" },
      group_key = { type = GroupKey, desc = "filter history by group key" },
      before = { name = "seconds", type = SC.Number, desc = "filter history for items updated at least this long ago" },
      since = { name = "seconds", type = SC.Number, desc = "filter history for items updated at most this long ago" },
      include_removed = {
        name = "true|false",
        type = SC.Boolean,
        desc = "whether to clear items that have have been removed (default: `true`)"
      },
      include_active = {
        name = "true|false",
        type = SC.Boolean,
        desc = "whether to clear items that have not been removed (default: `true`)"
      },
    }
  },
  clear_history = {
    desc = "Clear notifications history",
    func = function(args)
      args.group_key = args[1] or args.group_key
      require("fidget.notification").clear_history(args)
    end,
    args = {
      { name = "group_key", type = GroupKey, desc = "clear history by group key" },
      group_key = { type = GroupKey, desc = "clear history by group key" },
      before = { name = "seconds", type = SC.Number, desc = "filter history for items updated at least this long ago" },
      since = { name = "seconds", type = SC.Number, desc = "filter history for items updated at most this long ago" },
      include_removed = {
        name = "true|false",
        type = SC.Boolean,
        desc = "whether to clear items that have have been removed (default: true)"
      },
      include_active = {
        name = "true|false",
        type = SC.Boolean,
        desc = "whether to clear items that have not been removed (default: true)"
      },
    }
  },
  suppress = {
    desc = "Suppress notification window",
    func = function(args)
      require("fidget.notification").suppress(args[1])
    end,
    args = {
      { name = "suppress", type = SC.Boolean, desc = "whether to suppress (omitting this argument toggles suppression)" },
    },
  },
  lsp_suppress = {
    desc = "Suppress LSP progress notifications",
    func = function(args)
      require("fidget.progress").suppress(args[1])
    end,
    args = {
      { name = "suppress", type = SC.Boolean, desc = "whether to suppress (omitting this argument toggles suppression)" },
    },
  },
}

function SC.setup()
  vim.api.nvim_create_user_command(COMMAND_NAME, SC.handle_cmd(COMMAND_NAME, SC.subcommands), {
    desc = COMMAND_DESC,
    nargs = "+",
    complete = SC.handle_complete(SC.subcommands),
    force = true,
  })
end

--- Reflect on subcommands specification to generate README documentation.
---@return string docs
function SC.make_panvimdocs()
  local mddocs, vimdocs = {}, {}
  for _, kv in ipairs(sort_by_key(SC.subcommands)) do
    local name, subcmd = kv[1], kv[2]
    table.insert(mddocs, SC.mddoc(COMMAND_NAME, name, subcmd, 4))
    table.insert(vimdocs, SC.vimdoc(COMMAND_NAME, name, subcmd, "fidget"))
  end

  return string.format([[
<!-- {{{ Generated from fidget.commands.lua -->

## Commands

<!-- panvimdoc-include-comment

```vimdoc
*fidget-:Fidget* *:Fidget*
```

-->

Fidget exposes some of its Lua API functions through `:Fidget` sub-commands
(e.g., `:Fidget clear`), which support shell-like arguments and completion.
These sub-commands are documented below.

<!-- panvimdoc-ignore-start -->

### `:Fidget` sub-commands

%s

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment

```vimdoc
%s
```
-->

<!-- Generated from fidget.commands.lua }}} -->
]], table.concat(mddocs, "\n\n"), table.concat(vimdocs, "\n\n"))
end

-- print(SC.make_panvimdocs())

return SC
