local M = {}

--- Render the header of a group, consisting of a header and an optional icon.
--- Also returns the range of the icon text, for highlighting.
---
---@param         now   number    timestamp of current render frame
---@param         group NotificationGroup
---@return string header
---@return number icon_begin_col  byte-indexed
---@return number icon_end_col    byte-indexed; ignore if icon_end_col is -1
function M.render_group_header(now, group)
  local group_name = group.config.name
  if group_name ~= nil then
    if type(group_name) == "function" then
      group_name = group_name(now, group.items)
    end
  else
    group_name = tostring(group.key)
  end

  local group_icon = group.config.icon
  if type(group_icon) == "function" then
    group_icon = group_icon(now, group.items)
  end

  if group_icon then
    if group.config.icon_on_left then
      return string.format("%s %s", group_icon, group_name), 0, #group_icon
    end
    return string.format("%s %s", group_name, group_icon), #group_name + 1, -1
  else
    return group_name, -1, -1
  end
end

---@param now number timestamp of current render frame
---@param groups NotificationGroup[]
---@return NotificationView view
function M.render_view(now, groups)
  local width = 0
  local lines = {}
  local highlights = {}

  for _, group in ipairs(groups) do
    local group_header, icon_begin, icon_end = M.render_group_header(now, group)
    table.insert(lines, group_header)
    width = math.max(width, vim.fn.strdisplaywidth(group_header))
    -- Insert highlight for group name
    table.insert(highlights, {
      hl_group = group.config.name_style,
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
    })
    if icon_begin >= 0 then
      -- Insert highlight for group icon
      table.insert(highlights, {
        hl_group = group.config.icon_style,
        line = #lines - 1,
        col_start = icon_begin,
        col_end = icon_end,
      })
    end

    for _, item in ipairs(group.items) do
      local prev_line_count = #lines
      for line in string.gmatch(item.message, "([^\n]*)\n?") do
        width = math.max(width, vim.fn.strdisplaywidth(line))
        table.insert(lines, line)
      end
      -- The above capture always produces an extra empty string at the end,
      -- so we trim it off here.
      table.remove(lines)

      if prev_line_count ~= #lines and item.annote then
        -- Need to add the annotation to the first line of the item message
        local annote_line = prev_line_count + 1
        local sep = group.config.annote_separator or " "
        local msg = lines[annote_line]                              -- we are appending annote to this msg
        local line = string.format("%s%s%s", msg, sep, item.annote) -- to construct this line

        lines[annote_line] = line
        width = math.max(width, vim.fn.strdisplaywidth(line))

        -- Insert highlight for annote
        table.insert(highlights, {
          hl_group = item.style,
          line = annote_line - 1, -- 0-indexed
          col_start = vim.fn.strdisplaywidth(msg),
          col_end = -1,
        })
      end
    end
  end

  return {
    width = width,
    lines = lines,
    highlights = highlights,
  }
end

return M
