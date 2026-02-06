--- Helper methods used to render notification model elements into views.
---
local M = {}

local window = require("fidget.notification.window")
local logger = require("fidget.logger")

---@type Cache
local cache = require("fidget.notification.model").cache()

---@class Notification
---@field opts    NotificationOpts   rendering options
---@field lines   NotificationLine[] lines to place into buffer
---@field rows    integer            total amount of lines
---@field width   integer            width of longest line

---@class NotificationOpts
---@field upwards  boolean display from bottom to top
---@field position string  virtual text position

--- A list of highlighted tokens.
---@alias NotificationLine NotificationTokens[]|NotificationItems[]

--- NOTE: may need to double check this up
--- not sure I wrote the lls docs properly its a lot of nested table and cases
---
---@alias NotificationTokens { hdr: NotificationToken[] }
---@alias NotificationItems { line: NotificationItem[], opts: NotificationItemOpts }

---@class NotificationItem
---@field ecol integer
---@field scol integer
---@field text string
---@field hl   string[]

--- Per-message rendering options
---@class NotificationItemOpts
---@field position string

--- A tuple consisting of some text and a stack of highlights.
---@class NotificationToken : {[1]: string, [2]: string[]}

---@options notification.view [[
---@protected
--- Notifications rendering options
M.options = {
  --- Display notification items from bottom to top
  ---
  --- Setting this to true tends to lead to more stable animations when the
  --- window is bottom-aligned.
  ---
  ---@type boolean
  stack_upwards = true,

  --- Position of the text inside the window
  ---
  ---@type "left"|"right"
  text_position = "right",

  --- Automatically highlight notification using tree-sitter
  ---
  ---@type string|false
  highlight = "markdown_inline",

  --- Hide markdown tags with the "conceal" highlight name
  ---
  ---@type boolean
  hide_conceal = true,

  --- Indent messages longer than a single line
  ---
  --- Example: ~
  --->
  ---   align message style INFO
  ---       looks like this
  ---         when reflowed
  ---
  ---    align annote style INFO
  ---       looks like this when
  ---                   reflowed
  ---<
  ---
  ---@type "message"|"annote"
  align = "message",

  --- Separator between group name and icon
  ---
  --- Must not contain any newlines. Set to `""` to remove the gap between names
  --- and icons in all notification groups.
  ---
  ---@type string
  icon_separator = " ",

  --- Separator between notification groups
  ---
  --- Must not contain any newlines. Set to `false` to omit separator entirely.
  ---
  ---@type string|false
  group_separator = "--",

  --- Highlight group used for group separator
  ---
  ---@type string|false
  group_separator_hl = "Comment",

  --- Spaces to pad both sides of each non-empty line
  ---
  --- Useful for adding a visual gap between notification text and any buffer it
  --- may overlap with.
  ---
  ---@type integer
  line_margin = 1,

  --- How to render notification messages
  ---
  --- Messages that appear multiple times (have the same `content_key`) will
  --- only be rendered once, with a `cnt` greater than 1. This hook provides an
  --- opportunity to customize how such messages should appear.
  ---
  --- If this returns false or nil, the notification will not be rendered.
  ---
  --- See also:~
  ---     |fidget.notification.Config|
  ---     |fidget.notification.default_config|
  ---     |fidget.notification.set_content_key|
  ---
  ---@type fun(msg: string, cnt: number): (string|false|nil)
  render_message = function(msg, cnt) return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg) end,
}
---@options ]]

require("fidget.options").declare(M, "notification.view", M.options)

--- True when using GUI clients like neovide. Set before each render() phase.
---@type boolean
local is_multigrid_ui = false

---@return boolean is_multigrid_ui
function M.check_multigrid_ui()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.ext_multigrid then
      return true
    end
  end
  return false
end

---@return string
local function normal_hl()
  if window.options.normal_hl ~= "Normal" and window.options.normal_hl ~= "" then
    return window.options.normal_hl
  end
  return "Normal" -- default
end

--- The displayed width of some strings.
---
--- A simple wrapper around vim.fn.strwidth(), accounting for tab characters
--- manually.
---
--- We call this instead of vim.fn.strdisplaywidth() because that depends on
--- the state and size of the current window and buffer, which could be
--- anywhere.
---@param ... string
---@return integer len
local function strwidth(...)
  local w = 0
  for _, s in ipairs({ ... }) do
    w = w + vim.fn.strwidth(s) +
        vim.fn.count(s, "\t") * math.max(0, window.options.tabstop - 1)
  end
  return w
end

---@return integer len
local function line_margin()
  return 2 * M.options.line_margin
end

--- The displayed width of some strings, accounting for line_margin.
---@param ... string
---@return integer len
local function line_width(...)
  local w = strwidth(...)
  return w == 0 and w or w + line_margin()
end

---@return number
local function window_max()
  local pad = line_margin() + 4
  local win = window.max_width() - pad
  local ed = vim.opt.columns:get() - pad
  -- We ditch math.huge constant here because we need a limit to split lines
  if win <= 0 or ed < win then
    return ed
  end
  return win
end

--- Tokenize a string into a list of tokens.
---
--- A token is a contiguous sequence of characters or an individual non-space character.
--- Ignores consecutives whitespace.
---                      scol          ecol          word
---@alias Token  { [1]: integer, [2]: integer, [3]: string }
---
---@param source string
---@return Token[]
local function Tokenize(source)
  local pos = 0
  local tab = 0
  local res = {}
  local len = vim.fn.strchars(source)

  while pos < len do
    ---@type string
    local char = vim.fn.strcharpart(source, pos, 1)

    if char:match("%w") then
      local ptr = pos
      local word = { char }

      while ptr + 1 < len do
        local c = vim.fn.strcharpart(source, ptr + 1, 1)
        if not c:match("%w") then
          break
        end
        table.insert(word, c)
        ptr = ptr + 1
      end
      table.insert(res, { pos + tab, ptr + tab, table.concat(word) })
      pos = ptr + 1
    else
      if not char:match("%s") or char == "\t" then
        if char == "\t" then
          tab = tab + window.options.tabstop
        else
          table.insert(res, { pos + tab, pos + tab, char })
        end
      end
      pos = pos + 1
    end
  end
  return res
end

--- Pack an arbitrary text and its highlight inside a notification token.
---
---@param text string the text in this token
---@param ... string  highlights to apply to text
---@return NotificationToken
local function Token(text, ...)
  if is_multigrid_ui then
    return { text, { ... } }
  end
  return { text, { window.no_blend_hl, ... } }
end

--- Pack a notification token inside margin and returns a notification line.
---
---@param ... NotificationToken|NotificationItem
---@return NotificationLine
local function Line(...)
  if select("#", ...) == 0 then
    return {}
  end
  local margin = Token(string.rep(" ", M.options.line_margin))
  -- ... only expands to all args in last position of table
  local line = { margin, ... }
  line[#line + 1] = margin
  return line
end

--- Insert an annote or indent associated content line.
---
---@param line   table
---@param width  integer
---@param annote NotificationToken
---@param first  boolean
---@param left   boolean
---@return table   line
---@return integer width
local function Annote(line, width, annote, sep, first, left)
  if not annote then
    return line, width
  end
  if first then
    annote[1] = left and annote[1] .. sep or sep .. annote[1]
    if left then
      line = { annote, unpack(line) }
    else
      table.insert(line, annote)
    end
    width = width + line_width(annote[1])
  else
    -- Indent messages longer than a single line (see notification.view.align)
    if M.options.align == "message" then
      local len = vim.fn.strwidth(annote[1])
      local pad = Token(string.rep(sep, len))
      if left then
        line = { pad, unpack(line) }
      else
        table.insert(line, pad)
      end
      width = width + len
    end
  end
  return line, width
end

--- Returns the Treesitter highlight groups for a given source and language.
---
---@param source   string
---@param lang     string
---@param prev_hls table|nil
---@return table|nil hls
local function Highlight(source, lang, prev_hls)
  local ok, parser = pcall(function()
    return vim.treesitter.get_string_parser(source, lang)
  end)
  if not ok then
    logger.warn(parser)
    return
  end
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.get(lang, "highlights")
  if not query then
    return -- query file not found
  end

  local hls = {} -- holds captured hl
  if prev_hls then
    hls = prev_hls
  end
  local line = {}
  local prev_line = 0
  local prev_text, prev_range

  for id, node in query:iter_captures(tree:root(), source) do
    local text = vim.treesitter.get_node_text(node, source)
    if not text then
      goto continue
    end
    local name = query.captures[id]
    if name == "spell" or name == "nospell" then
      goto continue -- ignores spellcheck
    end

    -- Finds hl groups id if exists
    local hl = vim.fn.hlID(name)
    if hl == 0 then
      hl = vim.fn.hlID("@" .. name)
      if hl == 0 then
        hl = vim.fn.hlID(normal_hl()) -- fallback
      end
    end

    local srow, scol, _, ecol = node:range()
    if prev_line ~= srow then
      table.insert(hls, line) -- push to a new line
      line = {}
      prev_line = srow
    end
    if prev_text ~= text then
      prev_text = text
      prev_range = srow
    else
      if srow == prev_range then
        line[#line].hl = hl -- latest node takes priority
      end
    end
    -- Uses the same item renderer struct
    for _, token in ipairs(Tokenize(text)) do
      local t = {
        srow = srow,
        scol = scol,
        ecol = ecol,
        text = token[3],
        hl = hl
      }
      if not vim.tbl_contains(line,
            function(w)
              return vim.deep_equal(w, t)
            end, { predicate = true })
      then
        table.insert(line, t)
      end
    end
    ::continue::
  end
  if #line > 0 then
    table.insert(hls, line)
    return hls
  end
  return nil
end

---@return NotificationLine[]|nil lines
---@return integer                width
function M.render_group_separator()
  local line = M.options.group_separator
  if not line then
    return nil, 0
  end
  return { hdr = Line(Token(line, M.options.group_separator_hl)) }, line_width(line)
end

--- Render the header of a group, containing group name and icon.
---
---@param   now   number    timestamp of current render frame
---@param   group Group     group whose header we should render
---@return  NotificationLine[]|nil group_header
---@return  integer                width
function M.render_group_header(now, group)
  local group_name = group.config.name
  if type(group_name) == "function" then
    group_name = group_name(now, group.items)
  end

  local group_icon = group.config.icon
  if type(group_icon) == "function" then
    group_icon = group_icon(now, group.items)
  end

  local name_tok = group_name and Token(
    group_name, group.config.group_style or "Title"
  )
  local icon_tok = group_icon and Token(
    group_icon, group.config.icon_style or group.config.group_style or "Title"
  )

  if name_tok and icon_tok then
    ---@cast group_name string
    ---@cast group_icon string
    local sep_tok = Token(M.options.icon_separator or " ")
    local width = line_width(group_name, group_icon, M.options.icon_separator or " ")
    if group.config.icon_on_left then
      return { hdr = Line(icon_tok, sep_tok, name_tok) }, width
    else
      return { hdr = Line(name_tok, sep_tok, icon_tok) }, width
    end
  elseif name_tok then
    ---@cast group_name string
    return { hdr = Line(name_tok) }, line_width(group_name)
  elseif icon_tok then
    ---@cast group_icon string
    return { hdr = Line(icon_tok) }, line_width(group_icon)
  else
    -- No group header to render
    return nil, 0
  end
end

---@param items Item[]
---@return Item[] deduped
---@return table<any, integer> counts
function M.dedup_items(items)
  local deduped, counts = {}, {}
  for _, item in ipairs(items) do
    local key = item.content_key or item
    if counts[key] then
      counts[key] = counts[key] + 1
    else
      counts[key] = 1
      table.insert(deduped, item)
    end
  end
  return deduped, counts
end

--- Render a notification item, containing message and annote.
---
---@param item   Item
---@param config Config
---@param count  number
---@return NotificationItems|nil lines
---@return integer                 width
function M.render_item(item, config, count)
  if item.hidden then
    return nil, 0
  end

  local msg = M.options.render_message(item.message, count)
  if not msg then
    -- Don't render any lines for nil messages
    return nil, 0
  end

  local hl = {}
  if not is_multigrid_ui then
    table.insert(hl, window.no_blend_hl)
  end
  table.insert(hl, normal_hl())

  local hls
  local lang = item.lang and item.lang or M.options.highlight
  if lang and lang ~= "" then
    hls = Highlight(msg, lang)
    if hls then
      -- Also use inline for markdown
      if lang == "markdown" then
        hls = Highlight(msg, "markdown_inline", hls)
      end
    end
  end
  -- We have to keep track of extra lines added in tokens to not cause a desync with hls
  local extra_line = 0

  ---@type NotificationItem[]|NotificationToken[]
  local tokens = {}
  local annote = item.annote and Token(item.annote, item.style)
  local left = item.position and item.position == "left" or M.options.text_position == "left"
  local sep = config.annote_separator or " "

  local width = 0
  local max_width = window_max()

  for s in vim.gsplit(msg, "\n", { plain = true, trimempty = true }) do
    local line = {}
    local line_ptr = 0
    local prev_end = 0
    local next_start = 0
    local bytes_offset = 0

    for _, token in ipairs(Tokenize(s)) do
      if not token then
        break
      end
      local spacing = token[1] - prev_end
      local strlen = vim.fn.strwidth(token[3]) -- cell width

      -- Check if the line would overflow notification window if added as it is
      if line_ptr + strlen + spacing >= max_width - (annote and line_width(annote[1]) or 0) then
        if annote then
          line, width = Annote(line, width, annote, sep, #tokens == 0, left)
        end
        table.insert(tokens, Line(unpack(line))) -- push to newline
        next_start = token[1]
        extra_line = extra_line + 1              -- safeguard
        line_ptr = 0
        line = {}
      end

      ---@type NotificationItem
      local word = {
        scol = token[1] - next_start,
        ecol = token[2] - next_start + 1,
        text = token[3],
        hl = hl
      }
      table.insert(line, word)

      -- Adds treesitter highlights
      if hls then
        for _, tsline in ipairs(hls) do
          for _, ts in ipairs(tsline) do
            if ts.text == word.text and ts.srow + extra_line == #tokens then
              -- paint the whole line
              if ts.scol == 0 and ts.ecol == 0
                  or
                  word.scol >= ts.scol - next_start - bytes_offset then
                -- Removes concealed token
                if M.options.hide_conceal then
                  if ts.hl == vim.fn.hlID("conceal") then
                    line_ptr = line_ptr - strlen
                    word.text = ""
                  end
                end
                word.hl = vim.tbl_map(function(value)
                  if value ~= window.no_blend_hl then value = ts.hl end
                  return value
                end, word.hl)
              end
            end
          end
        end
      end
      -- Stores extra bytes needed to sync hls
      if #token[3] > strlen then
        bytes_offset = bytes_offset + #token[3]
      end
      prev_end = token[2] + 1
      line_ptr = line_ptr + strlen + spacing
      width = math.max(width, line_ptr + line_margin())
    end
    if annote then
      line, width = Annote(line, width, annote, sep, #tokens == 0, left)
    end
    table.insert(tokens, Line(unpack(line)))
  end
  -- The message is an empty string but there's an annotation to render
  if #tokens == 0 and annote then
    tokens = { Line(annote) }
  end
  return {
    line = tokens,
    --- Options to be passed to window render for this notification
    --- For now only text position is used
    ---@type NotificationItemOpts
    opts = { position = item.position }
  }, width
end

--- Render notifications into lines and highlights.
---
---@param now number timestamp of current render frame
---@param groups Group[]
---@return Notification
function M.render(now, groups)
  is_multigrid_ui = M.check_multigrid_ui()

  ---@type NotificationLine[][]
  local chunks = {}
  local max_width = 0

  cache.render_item = cache.render_item or {}
  cache.group_header = cache.group_header or {}
  cache.group_sep = cache.group_sep or { nil, nil } -- sep, width

  local size = window_max()
  local max = math.max

  -- Force rendering when the length of the window change
  local resized = cache.render_width and cache.render_width ~= size or false

  if not cache.render_width or resized then
    cache.render_width = size
  end

  for idx, group in ipairs(groups) do
    if idx ~= 1 then
      if resized or not cache.group_sep[1] then
        cache.group_sep[1], cache.group_sep[2] = M.render_group_separator()
      end
      chunks[#chunks + 1] = cache.group_sep[1]
      max_width = max(max_width, cache.group_sep[2])
    end

    if group.config.name then
      local icon = group.config.icon
      if type(icon) == "function" then
        icon = group.config.icon(now, group.items)
      end
      if not cache.group_header[group.config.name] then
        cache.group_header[group.config.name] = { nil, nil, nil } -- hdr, width, icon
      end
      local hdr = cache.group_header[group.config.name]

      if resized or not icon or hdr and icon ~= hdr[3] then
        hdr[1], hdr[2] = M.render_group_header(now, group)
        hdr[3] = icon
      end
      chunks[#chunks + 1] = hdr[1]
      max_width = max(max_width, hdr[2])
    end

    local items, counts = M.dedup_items(group.items)

    for i, item in ipairs(items) do
      if group.config.render_limit and i > group.config.render_limit then
        -- Don't bother rendering the rest (though they still exist)
        break
      end
      local key = item.content_key or item
      local count = counts[key]
      -- Caches lsp messages when update_hook is false
      if not group.config.update_hook and group.config.priority then
        key, count = item.message, 1
      end

      if not cache.render_item[key] then
        cache.render_item[key] = { nil, nil, nil } -- it, width, count
      end
      local it = cache.render_item[key]

      if resized or count ~= it[3] then
        it[1], it[2] = M.render_item(item, group.config, count)
        it[3] = count
      end
      chunks[#chunks + 1] = it[1]
      max_width = max(max_width, it[2])
    end
  end

  local start, stop, step
  if M.options.stack_upwards then
    start, stop, step = #chunks, 1, -1
  else
    start, stop, step = 1, #chunks, 1
  end

  local rows = 0
  local lines = {}
  for i = start, stop, step do
    ---@cast chunks NotificationLine
    if chunks[i] and (chunks[i].hdr or chunks[i].line) then
      rows = rows + (chunks[i].hdr and 1 or 0) + (chunks[i].line and #chunks[i].line or 0)
      lines[#lines + 1] = chunks[i]
    end
  end
  ---@type Notification
  return {
    rows = rows,
    lines = lines,
    width = max_width,
    ---@type NotificationOpts
    opts = {
      upwards = M.options.stack_upwards,
      position = M.options.text_position,
    }
  }
end

--- Display notification items in Neovim messages.
---
--- TODO(j-hui): this is not very configurable, but I'm not sure what options to
--- expose to strike a balance between flexibility and simplicity. Then again,
--- nothing done here is "special"; the user can easily (and is encouraged to)
--- write a custom `echo_history()` by consuming the results of `get_history()`.
---
---@param items HistoryItem[]
function M.echo_history(items)
  for _, item in ipairs(items) do
    local is_multiline_msg = string.find(item.message, "\n") ~= nil

    local chunks = {}

    table.insert(chunks, { vim.fn.strftime("%c", item.last_updated), "Comment" })

    -- if item.group_icon and #item.group_icon > 0 then
    --   table.insert(chunks, { " ", "MsgArea" })
    --   table.insert(chunks, { item.group_icon, "Special" })
    -- end

    if item.group_name and #item.group_name > 0 then
      table.insert(chunks, { " ", "MsgArea" })
      table.insert(chunks, { item.group_name, "Special" })
    end

    table.insert(chunks, { " | ", "Comment" })

    if item.annote and #item.annote > 0 then
      table.insert(chunks, { item.annote, item.style })
    end

    if is_multiline_msg then
      table.insert(chunks, { "\n", "MsgArea" })
    else
      table.insert(chunks, { " ", "MsgArea" })
    end

    table.insert(chunks, { item.message, "MsgArea" })

    if is_multiline_msg then
      table.insert(chunks, { "\n", "MsgArea" })
    end

    vim.api.nvim_echo(chunks, false, {})
  end
end

return M
