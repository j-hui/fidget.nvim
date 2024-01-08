--- Helper methods used to render notification model elements into views.
---
--- TODO: partial/in-place rendering, to avoid building new strings.
local M = {}

---@class NotificationView
---@field width       number                    the maximum width of any line
---@field lines       string[]                  text to show in the notification
---@field highlights  NotificationHighlight[]   buf_add_highlight() params, applied in order

---@class NotificationRenderItem
---@field lines      string[]                 displayed message for the item
---@field highlights NotificationHighlight[]  buf_add_highlight() params for lines field

---@class NotificationHighlight
---@field hl_group    string    what highlight group to add
---@field line        number    (0-indexed) line number to add highlight
---@field col_start   number    (byte-indexed) column to start highlight
---@field col_end     number    (byte-indexed) column to end highlight

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

  --- How to render notification messages
  ---
  --- Messages that appear multiple times (have the same `content_key`) will
  --- only be rendered once, with a `cnt` greater than 1. This hook provides an
  --- opportunity to customize how such messages should appear.
  ---
  --- Note that if this returns an empty string, the notification will not be
  --- rendered.
  ---
  --- See also:~
  ---     |fidget.notification.Config|
  ---     |fidget.notification.default_config|
  ---     |fidget.notification.set_content_key|
  ---
  ---@type fun(msg: string, cnt: number): string
  render_message = function(msg, cnt) return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg) end,
}
---@options ]]

require("fidget.options").declare(M, "notification.view", M.options)

--- Render group separator item.
---
---@return NotificationRenderItem|nil group_separator
function M.render_group_separator()
  if not M.options.group_separator then
    return nil
  end

  return {
    lines = { M.options.group_separator or nil },
    highlights = {
      M.options.group_separator_hl and {
        hl_group = M.options.group_separator_hl or nil,
        line = 0,
        col_start = 0,
        col_end = -1,
      }
    }
  }
end

--- Render the header of a group, containing group name and icon.
---
---@param   now   number    timestamp of current render frame
---@param   group Group
---@return  NotificationRenderItem|nil group_header
function M.render_group_header(now, group)
  local group_name = group.config.name
  if type(group_name) == "function" then
    group_name = group_name(now, group.items)
  end

  local group_icon = group.config.icon
  if type(group_icon) == "function" then
    group_icon = group_icon(now, group.items)
  end

  if group_name == nil and group_icon == nil then
    -- No group header to render
    return nil
  end

  local lines, highlights = {}, {}

  if group_name and group_icon then
    -- Both group_name and group_icon are present, lay them out next to each other
    if group.config.icon_on_left then
      table.insert(lines, string.format("%s%s%s", group_icon, M.options.icon_separator, group_name))
      table.insert(highlights, {
        hl_group = group.config.group_style or "Title",
        line = 0,
        col_start = 0,
        col_end = -1,
      })
      if group.config.icon_style then
        table.insert(highlights, {
          hl_group = group.config.icon_style,
          line = 0,
          col_start = 0,
          col_end = #group_icon,
        })
      end
    else -- not icon_on_left, AKA icon on right
      -- NOTE: this branch represents the most common case (default options)
      table.insert(lines, string.format("%s%s%s", group_name, M.options.icon_separator, group_icon))
      table.insert(highlights, {
        hl_group = group.config.group_style or "Title",
        line = 0,
        col_start = 0,
        col_end = -1,
      })
      if group.config.icon_style then
        table.insert(highlights, {
          hl_group = group.config.icon_style,
          line = 0,
          col_start = #group_name + #M.options.icon_separator,
          col_end = -1,
        })
      end
    end
  else
    if group_name then
      table.insert(lines, group_name)
      table.insert(highlights, {
        hl_group = group.config.group_style or "Title",
        line = 0,
        col_start = 0,
        col_end = -1,
      })
    elseif group_icon then
      table.insert(lines, group_icon)
      table.insert(highlights, {
        hl_group = group.config.icon_style or group.config.group_style or "Title",
        line = 0,
        col_start = 0,
        col_end = -1,
      })
    end
  end
  return { lines = lines, highlights = highlights }
end

--- Render a notification item, containing message and annote.
---
---@param item   Item
---@param config Config
---@param count  number
---@return       NotificationRenderItem|nil render_item
function M.render_item(item, config, count)
  if item.hidden then
    return nil
  end

  local lines, highlights = {}, {}

  local msg = M.options.render_message(item.message, count)
  for line in vim.gsplit(msg, "\n", { plain = true, trimempty = true }) do
    table.insert(lines, line)
  end

  if #lines == 0 then
    -- Don't render empty messages
    return nil
  end

  if item.annote then
    local line1 = lines[1] -- Append annote to first line
    local col_start = #line1
    local sep = config.annote_separator or " "
    line1 = string.format("%s%s%s", line1, sep, item.annote)
    lines[1] = line1

    -- Insert highlight for annote
    table.insert(highlights, {
      hl_group = item.style,
      line = 0,              -- 0-indexed
      col_start = col_start, -- byte-indexed
      col_end = -1,
    })
  end

  return { lines = lines, highlights = highlights }
end

--- Render notifications into lines and highlights.
---
---@param now number timestamp of current render frame
---@param groups Group[]
---@return NotificationView view
function M.render(now, groups)
  ---@type NotificationRenderItem[]
  local render_items = {}

  for idx, group in ipairs(groups) do
    if idx ~= 1 then
      local separator = M.render_group_separator()
      if separator then
        table.insert(render_items, separator)
      end
    end

    local group_header = M.render_group_header(now, group)
    if group_header then
      table.insert(render_items, group_header)
    end

    local counts = {}
    for _, item in ipairs(group.items) do
      local content_key = item.content_key
      if content_key ~= nil then
        if counts[content_key] then
          counts[content_key] = counts[content_key] + 1
        else
          counts[content_key] = 1
        end
      end
    end

    local i = 1
    for _, item in ipairs(group.items) do
      if group.config.render_limit and i > group.config.render_limit then
        -- Don't bother rendering the rest (though they still exist)
        break
      end
      local content_key = item.content_key
      if content_key == nil or counts[content_key] then
        local count = 1
        if content_key ~= nil then
          count = counts[content_key]
          counts[content_key] = nil
        end

        local render_item = M.render_item(item, group.config, count)
        if render_item then
          table.insert(render_items, render_item)
          i = i + 1
        end
      end
    end
  end

  local width, lines, highlights = 0, {}, {}

  local start, stop, step
  if M.options.stack_upwards then
    start, stop, step = #render_items, 1, -1
  else
    start, stop, step = 1, #render_items, 1
  end

  for i = start, stop, step do
    local item, offset = render_items[i], #lines
    for _, line in ipairs(item.lines) do
      width = math.max(width, vim.fn.strdisplaywidth(line))
      table.insert(lines, line)
    end
    for _, highlight in ipairs(item.highlights) do
      highlight.line = highlight.line + offset
      table.insert(highlights, highlight)
    end
  end

  return {
    width = width,
    lines = lines,
    highlights = highlights,
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
