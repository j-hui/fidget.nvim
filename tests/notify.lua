local logger = require("fidget.logger")
local notif = require("fidget.notification")

local str = {
  line_msg = "A notification message!",
  line_msg_tab = "A notification\tmessage\twith\ttab!",
  line_msg_utf8 = "󰢱 こんにちは – Hello Привет  – سلام !",
  line_msg_lang = "print([x**2 for x in range(1, 6)])",
  line_msg_log = "A notification message with log level!",
  line_msg_annote = "A notification message with annote!",
  line_msg_markdown = "A **notification** message `with` ~log~ markdown!",
  line_msg_markdown_utf8 = "󰢱 **こんにちは** – ~Bye~ Hello [Привет]  – سلام !",
  long_line_msg = "This is a very very long line that stretches beyond the usual " ..
      "notification limit and is meant to test how the UI handles overflow.",
  long_line_markdown = "This is a very **very** long line that stretches `beyond` the usual " ..
      "notification ~limit~ and is meant to [test] how the _UI_ handles overflow.",
  long_line_markdown_utf8 = "This is a very **very** long `こんにちは世界` ! " ..
      "🌍🚀✨💡🔔🎉🌟🌈🌹🍀🍕🎵📚🔬🖌️🛠️🎨🗝️⚙️🧰🧲 notification ~limit~ and is meant to [t€st] overfløw.",
  multiline_msg = "align message style\nlooks like this\nwhen reflowed",
  multiline_msg_utf8 = "align message🎵 style\nlooks🌈🌹🍀🍕like this\nwh€n reflowed",
  block_lua = [[
-- This is a     `lua` function!

function abc()
    print("Hello, world!")
    local a = 2 * 6 -- inline comment
    return a
end
]],
  block_go = [[
package main

import "fmt"

func main() {
  // this is 	a `comment`
  fmt.Println("Hello, ~world~!")
}
]],
  block_md = [[
# A cool title

**Features in bold**
- Lightweight and fast
- Easy to integrate with `this feature`
- Open sourced 

> Some notes here, and in a "quote".

Sample of `cøde` here:
```lua
function foo()
  print("some	tab here")
end
```
]]
}

-- a notification window with a message
local function line_msg()
  notif.notify(str.line_msg)
end

-- a notification window with a message, tab indented
local function line_msg_tab()
  notif.window.options.tabstop = 4
  notif.notify(str.line_msg_tab)
end

-- a notification window with a message, support utf8
local function line_msg_utf8()
  notif.notify(str.line_msg_utf8)
end

-- a notification window with a message, python highlighted
local function line_msg_lang()
  notif.notify(str.line_msg_lang, nil, { lang = "python" })
end

-- a notification window with INFO annote
local function line_msg_log()
  notif.notify(str.line_msg_log, 2)
end

-- a notification window with INFO annote, left aligned
local function line_msg_left()
  notif.notify(str.line_msg, 2, { position = "left" })
end

-- a notification window with foo annote
local function line_msg_annote()
  notif.notify(str.line_msg_annote, nil, { annote = "foo" })
end

-- a notification window with markdown highlight, tags removed
local function line_msg_markdown()
  notif.notify(str.line_msg_markdown)
end

-- a notification window with markdown highlight, tags removed, support utf8
local function line_msg_markdown_utf8()
  notif.notify(str.line_msg_markdown_utf8)
end

-- a notification window with markdown highlight, tags visible
local function line_msg_markdown_show_conceal()
  notif.view.options.hide_conceal = false
  notif.notify(str.line_msg_markdown)
end

-- a notification window with markdown text, no highlight
local function line_msg_markdown_highlight_off()
  notif.view.options.highlight = false
  notif.notify(str.line_msg_markdown)
end

-- a notification window with markdown highlight, tags removed
-- blending highlight follows global colorscheme change
-- NOTE: reproduces #298, this test will fail until fixed
local function line_msg_colorscheme()
  vim.cmd("colorscheme blue")
  notif.notify(str.line_msg_markdown)
end

-- a notification window, single line overflow split in multi lines
local function long_line_msg()
  notif.notify(str.long_line_msg)
end

-- a notification window, single line overflow split in multi lines, left aligned
-- respect max_width with no overflow when resized
local function long_line_msg_left()
  notif.notify(str.long_line_msg, nil, { position = "left" })
end

-- a notification window, single line overflow split in multi lines
-- respect max_width with no overflow
local function long_line_msg_resized()
  notif.notify(str.long_line_msg)
  notif.window.options.max_width = 40
end

-- a notification window, single line overflow split in multi with INFO annote
-- aligned by annote (respecting line_margin)
local function long_line_msg_annote()
  notif.view.options.align = "annote"
  notif.notify(str.long_line_msg, 2)
end

-- a notification window, single line overflow split in multi lines with INFO annote
-- aligned by message (respecting line_margin)
local function long_line_msg_align()
  notif.view.options.align = "message"
  notif.notify(str.long_line_msg, 2)
end

-- a notification window, single line overflow split in multi lines
-- each lines are highlighted using markdown_inline even when resized
local function long_line_msg_markdown()
  notif.notify(str.long_line_markdown)
end

-- a notification window, single line overflow split in multi lines
-- each lines are highlighted using markdown_inline even when resized
-- support utf8
local function long_line_msg_markdown_utf8()
  notif.notify(str.long_line_markdown_utf8)
end

-- a notification window, multi lines
local function multi_line_msg()
  notif.notify(str.multiline_msg)
end

-- a notification window, multi lines, utf8
local function multi_line_msg_utf8()
  notif.notify(str.multiline_msg_utf8)
end

-- a notification window, multi lines with foo annote and aligned by annote
local function multi_line_msg_annote()
  notif.view.options.align = "annote"
  notif.notify(string.gsub(str.multiline_msg, "message", "annote"), nil, { annote = "foo" })
end

-- a notification window, multi lines with foo annote and aligned by message
local function multi_line_msg_align()
  notif.view.options.align = "message"
  notif.notify(str.multiline_msg, nil, { annote = "foo" })
end

-- a notification window, multi lines with one line overflowing the window split in multi lines
-- the message content is set with an INFO annote
local function multi_line_msg_overflow()
  notif.notify(str.multiline_msg .. "\n" .. str.long_line_msg, 2)
end

-- a notification window with an highlighted [[block of lua code]], left aligned
-- colors should be the same as filetype=lua
local function block_msg_lua()
  notif.view.options.highlight = "lua"
  notif.notify(str.block_lua, nil, { position = "left" })
end

-- a notification window with an highlighted [[block of go code]], left aligned
-- colors should be the same as filetype=go
local function block_msg_go()
  notif.view.options.highlight = "go"
  notif.notify(str.block_go, nil, { position = "left" })
end

-- a notification window with an highlighted [[block of markdown text]], right aligned
-- colors should be the same as filetype=markdown
--
-- NOTE: mixing highlight with ```lang\n text``` is not yet supported
local function block_msg_markdown()
  notif.view.options.highlight = "markdown"
  notif.notify(str.block_md)
end

-- a notification window, empty of message with a title
local function empty_msg()
  notif.notify("")
end

-- a notification window, empty of message with <- empty msg annote
local function empty_msg_annote()
  notif.notify("", nil, { annote = "<- empty msg" })
end

-- a notification window with empty annote -> message with empty annote
local function empty_annote()
  notif.notify("empty annote ->", nil, { annote = "" })
end

-- a notification window without group name
local function empty_name()
  notif.default_config.name = nil
  notif.notify("empty group name")
end

-- a notification window with a group name but no icon
local function empty_icon()
  notif.default_config.icon = nil
  notif.notify("empty group icon")
end

-- the notification window is cleared and closed
local function clear()
  notif.clear()
  -- clean cache etc if needed here
end

---
local M = {
  ---               name         test         time offset
  ---@type table { [1]: string, [2]: function, [3]: number|nil }
  test = {
    { "line_msg",                        line_msg,                        0 },
    { "line_msg_tab",                    line_msg_tab,                    0 },
    { "line_msg_utf8",                   line_msg_utf8,                   0 },
    { "line_msg_log",                    line_msg_log,                    0 },
    { "line_msg_lang",                   line_msg_lang,                   0 },
    { "line_msg_left",                   line_msg_left,                   0 },
    { "line_msg_annote",                 line_msg_annote,                 0 },
    { "line_msg_markdown",               line_msg_markdown,               0 },
    { "line_msg_markdown_utf8",          line_msg_markdown_utf8,          0 },
    { "line_msg_markdown_show_conceal",  line_msg_markdown_show_conceal,  0 },
    { "line_msg_markdown_highlight_off", line_msg_markdown_highlight_off, 0 },
    { "line_msg_colorscheme",            line_msg_colorscheme,            0 },
    { "clear",                           clear,                           4 },
    { "long_line_msg",                   long_line_msg,                   0 },
    { "long_line_msg_left",              long_line_msg_left,              0 },
    { "long_line_msg_resized",           long_line_msg_resized,           0 },
    { "long_line_msg_annote",            long_line_msg_annote,            1 },
    { "long_line_msg_align",             long_line_msg_align,             0 },
    { "long_line_msg_markdown",          long_line_msg_markdown,          0 },
    { "long_line_msg_markdown_utf8",     long_line_msg_markdown_utf8,     0 },
    { "clear",                           clear,                           4 },
    { "multiline_msg",                   multi_line_msg,                  0 },
    { "multiline_msg_utf8",              multi_line_msg_utf8,             0 },
    { "multi_line_msg_annote",           multi_line_msg_annote,           0 },
    { "multi_line_msg_align",            multi_line_msg_align,            0 },
    { "multi_line_msg_overflow",         multi_line_msg_overflow,         0 },
    { "clear",                           clear,                           4 },
    { "block_msg_lua",                   block_msg_lua,                   0 },
    { "clear",                           clear,                           1 },
    { "block_msg_go",                    block_msg_go,                    0 },
    { "clear",                           clear,                           1 },
    { "block_msg_markdown",              block_msg_markdown,              0 },
    { "clear",                           clear,                           1 },
    { "empty_name",                      empty_name,                      0 },
    { "clear",                           clear,                           1 },
    { "empty_icon",                      empty_icon,                      0 },
    { "clear",                           clear,                           1 },
    { "empty_msg",                       empty_msg,                       0 },
    { "empty_msg_annote",                empty_msg_annote,                0 },
    { "empty_annote",                    empty_annote,                    0 },
  },
}

function M.run()
  logger.options.level = vim.log.levels.DEBUG
  logger.debug("-- test --")

  notif.window.options.border = "single"
  -- notif.view.options.stack_upwards = true
  -- notif.view.options.text_position = "left"
  -- notif.view.options.line_margin = 8
  -- notif.default_config.ttl = 500

  M.config = {
    colorscheme = vim.g.colors_name or "default",
    default = vim.deepcopy(notif.default_config),
    window = vim.deepcopy(notif.window.options),
    view = vim.deepcopy(notif.view.options),
  }
  local offset = 0

  for time, test in ipairs(M.test) do
    if #test == 2 then
      test[3] = 0
    end
    local t = vim.uv.new_timer()
    if t then
      offset = offset + test[3]
      t:start((time + offset) * 1000, 0, vim.schedule_wrap(
        function()
          t:stop()
          local ok, err = pcall(
            function()
              -- start test with a clean config
              if M.config then
                if M.config.colorscheme ~= vim.g.colors_name then
                  vim.cmd("colorscheme " .. M.config.colorscheme)
                end
                for k, v in pairs(M.config.default) do notif.default_config[k] = v end
                for k, v in pairs(M.config.window) do notif.window.options[k] = v end
                for k, v in pairs(M.config.view) do notif.view.options[k] = v end
              end
              logger.debug("run " .. test[1])
              test[2]()
            end)
          if not ok then
            logger.debug("=> " .. err)
          end
          t:close()
        end
      ))
    end
  end
end

return M
