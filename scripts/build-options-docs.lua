local help_text = string.format([[
Extract options and documentation from Lua files.

usage: %s [OPTIONS..] <FILES..>

options:
  -h, --help        display help
  --tag <PREFIX>    tag prefix
  --strip <NUM>     strip up to <NUM> characters of whitespace from doc strings (default: 0)
  --indent <NUM>    indentation amount (default: 4)
  --width <NUM>     textwidth (default: 78)
  --toc             print table of contents (default)
  --no-toc          do not print table of contents
]], arg[0])

---@class OptionsModule
---@field filename string
---@field prefix string|nil
---@field docs string[]
---@field options Option[]|nil
---@field shortname string
---@field tag string
---@field link string
---@field title_line string

---@class Option
---@field docs string[]
---@field name string|nil
---@field default string[]|nil
---@field tag string
---@field title_line string

local opts = {
  help = false,
  tag_prefix = "",
  strip = "0",
  strip_num = 0,
  indent = "4",
  indent_num = 4,
  width = "78",
  width_num = 78,
  toc = true,
}

---@type string[]
local files = {}

---@type OptionsModule[]
local modules = {}

---@type string|nil
local next_option = nil

-- Parse arguments
for _, v in ipairs(arg) do
  if next_option ~= nil then
    opts[next_option] = v
    next_option = nil
  elseif v == "--help" then
    opts.help = true
  elseif v == "--tag" then
    next_option = "tag_prefix"
  elseif v == "--strip" then
    next_option = "strip"
  elseif v == "--indent" then
    next_option = "indent"
  elseif v == "--width" then
    next_option = "width"
  elseif v == "--toc" then
    opts.toc = true
  elseif v == "--no-toc" then
    opts.toc = false
  else
    table.insert(files, v)
  end
end

if opts.help then
  print(help_text)
  os.exit(0)
end

--- Convert opt name to number
---@param name string
---@param flag string
local function flag_to_num(name, flag)
  local num = tonumber(opts[name])
  if num then
    opts[name .. "_num"] = num
  else
    print("Error: " .. flag .. " <NUM> must be a number, instead got: " .. opts[name])
    os.exit(1)
  end
end

flag_to_num("strip", "--strip")
flag_to_num("indent", "--indent")
flag_to_num("width", "--width")

-- my favorite kind of for loop, the ones that do things
for _, filename in ipairs(files) do
  local f = io.open(filename, "rb")
  if not f then
    print("Error: file does not exist: " .. filename)
    os.exit(1)
  else
    --- Current module
    ---@type OptionsModule
    local module = {
      filename = filename,
      docs = {},
      shortname = "Options from " .. filename,
      tag = "",
      link = "",
      title_line = ""
    }

    --- Current option
    ---@type Option
    local option = { docs = {}, tag = "", title_line = "" }

    --- Current indentation level
    ---@type number
    local indent = 0

    for line in f:lines("*l") do
      ---@type boolean, number|nil, string|nil, string|nil, string|nil
      local done, found, cap1, cap2, cap3
      done = false

      -- Look for ---@options (prefix) [[
      found, _, cap1 = string.find(line, "%-%-%-@options%s*([%w%._-]*)%s*%[%[")
      if found then
        if module.prefix ~= nil then
          print("Error: file contains multiple @options tags: " .. filename)
          os.exit(1)
        end
        module.prefix = cap1
        done = true
      end

      -- Look for ---@options ]]
      found = string.find(line, "%-%-%-@options %]%]")
      if not done and found then
        table.insert(modules, module)
        done = true
        -- For simplicity, we assume there is only one options block per module
        break
      end

      if not done and module.prefix then
        -- We are already in the @options block
        if module.options == nil then
          -- We are not yet in the options table
          if string.find(line, "%.options%s*=%s*{%s*$") then
            -- We found the line that opens the options table
            module.options = {}
          else
            -- Look for ---(module docs)
            found, _, cap1 = string.find(line, "%-%-%-(.*)")
            if found then
              table.insert(module.docs, cap1)
            end
          end
        else
          if option.name ~= nil then
            -- We're still looking for the end of the default value
            -- Get indentation level
            _, _, cap1 = string.find(line, "^(%s*)")
            if #cap1 == indent and string.sub(line, #line, #line) == "," then
              -- Same indentation level + comma at end, probably ended default value
              table.insert(option.default, string.sub(line, indent + 1, #line - 1))
              table.insert(module.options, option)
              option = { docs = {}, tag = "", title_line = "" }
            else
              -- Different indentation level; consume line (minus indentation) and keep going
              table.insert(option.default, string.sub(line, indent + 1))
            end
          else
            -- Look for option docs
            found, _, cap1 = string.find(line, "%-%-%-(.*)")
            if not done and found then
              table.insert(option.docs, cap1)
              done = true
            end

            -- Look for option = default_value,
            found, _, cap1, cap2, cap3 = string.find(line, "^%s*([%w_]*)%s*=%s*(.-)(,?)$")
            if not done and found then
              option.name = cap1
              option.default = { cap2 }
              if cap3 == "," then
                -- This is probably a single-line default value
                table.insert(module.options, option)
                option = { docs = {}, tag = "", title_line = "" }
              else
                -- oh god oh geez this is a multi-line default value.
                -- Use indentation level as heuristic for end of default value.
                _, _, cap1 = string.find(line, "^(%s*)")
                indent = #cap1
              end
            end
          end
        end
      end
    end
  end
end


local indent = string.rep(" ", opts.indent_num)

-- Preprocess modules
for _, module in ipairs(modules) do
  local mod_docs = {}
  for _, line in ipairs(module.docs) do
    if line == "@protected" then
      -- skip
    else
      local _, _, padding = string.find(line, "^(%s*)")
      table.insert(mod_docs, string.sub(line, math.min(#padding, opts.strip_num) + 1))
    end
  end
  module.docs = mod_docs
  module.shortname = module.docs[1] or module.shortname

  module.tag = #opts.tag_prefix > 0 and string.format("%s.%s", opts.tag_prefix, module.prefix) or module.prefix or
      "ERROR.NO.TAG"
  module.link = string.format("|%s|", module.tag)
  module.tag = string.format("*%s*", module.tag)
  module.title_line = string.format("%s%s%s", module.shortname,
    string.rep(" ", math.max(opts.width_num - (#module.shortname + #module.tag), 2)), module.tag)

  local options = {}
  for _, option in ipairs(module.options) do
    -- Only consider documented options
    if #option.docs > 0 then
      local name = #module.prefix > 0 and string.format("%s.%s", module.prefix, option.name) or option.name
      local tag = #opts.tag_prefix > 0 and string.format("%s.%s", opts.tag_prefix, name) or name or "ERROR.NO.TAG"
      tag = string.format("*%s*", tag)
      option.tag = tag
      option.title_line = string.format("%s%s%s", name, string.rep(" ", math.max(opts.width_num - (#name + #tag), 2)),
        tag)

      local docs, type = {}, nil
      for _, line in ipairs(option.docs) do
        if string.sub(line, 1, 1) == "@" then
          if string.sub(line, 1, 6) == "@type " then
            type = string.sub(line, 7)
          end
        elseif line:sub(1, 1) == ">" then
          table.insert(docs, line)
        elseif line:sub(1, 1) == "<" then
          table.insert(docs, line)
        elseif line == "" then
          table.insert(docs, line)
        else
          local _, _, padding = string.find(line, "^(%s*)")
          table.insert(docs, string.format("%s%s", indent, string.sub(line, math.min(#padding, opts.strip_num) + 1)))
        end
      end

      if type then
        table.insert(docs, string.format("%sType: ~", indent))
        table.insert(docs, string.format("%s%s`%s`", indent, indent, type))
        table.insert(docs, "")
      end

      if #option.default == 1 then
        table.insert(docs, string.format("%sDefault: ~", indent))
        table.insert(docs, string.format("%s%s`%s`", indent, indent, option.default[1]))
        table.insert(docs, "")
      elseif #option.default > 1 then
        table.insert(docs, string.format("%sDefault: ~", indent))
        table.insert(docs, ">lua")
        for _, line in ipairs(option.default) do
          table.insert(docs, string.format("%s%s%s", indent, indent, line))
        end
        table.insert(docs, "<")
      end
      option.docs = docs
      table.insert(options, option)
    end
  end
  module.options = options
end

local function rule()
  print(string.rep("=", opts.width_num))
end

local function blank()
  if vim then
    -- For some reason this is necessary when running with nvim
    print("\n")
  else
    print()
  end
end

if opts.toc then
  rule()
  local title, toc_tag = "Table of Contents", "*toc*"
  if #opts.tag_prefix > 0 then
    toc_tag = string.format("*%s.toc*", opts.tag_prefix)
  end
  print(string.format("%s%s%s", title, string.rep(" ", math.max(opts.width_num - (#title + #toc_tag), 2)), toc_tag))
  blank()

  for _, module in ipairs(modules) do
    if #module.options > 0 then
      print(string.format("%s %s %s", module.shortname,
        string.rep(".", math.max(opts.width_num - 2 - (#module.shortname + #module.link), 0)), module.link))
    end
  end
  blank()
  blank()
end

for _, module in ipairs(modules) do
  -- Only consider modules with non-zero number of options
  if #module.options > 0 then
    rule()
    print(module.title_line)
    blank()
    blank()

    for _, option in ipairs(module.options) do
      print(option.title_line)
      blank()
      for _, line in ipairs(option.docs) do
        if line == "" then
          blank()
        else
          print(line)
        end
      end
      blank()
    end
  end
end
