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
---@return       NotificationRenderItem|nil render_item
function M.render_item(item, config)
  local lines, highlights = {}, {}

  for line in vim.gsplit(item.message, "\n", { plain = true, trimempty = true }) do
    table.insert(lines, line)
  end

  if #lines == 0 then
    -- Don't render empty messages
    return nil
  end

  if item.annote then
    local msg = lines[1] -- Append annote to first line of message
    local sep = config.annote_separator or " "
    local line = string.format("%s%s%s", msg, sep, item.annote)
    lines[1] = line

    -- Insert highlight for annote
    table.insert(highlights, {
      hl_group = item.style,
      line = 0,         -- 0-indexed
      col_start = #msg, -- byte-indexed
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

    for i, item in ipairs(group.items) do
      if group.config.render_limit and i > group.config.render_limit then
        -- Don't bother rendering the rest (though they still exist)
        break
      end
      local render_item = M.render_item(item, group.config)
      if render_item then
        table.insert(render_items, render_item)
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

return M
