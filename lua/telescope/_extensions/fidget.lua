local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local notification = require("fidget.notification")
local pickers = require("telescope.pickers")
local telescope = require("telescope")
local previewers = require("telescope.previewers")

--- Format HistoryItem, used in Telescope or Neovim messages.
---
---@param entry HistoryItem
---@return table
local format_entry = function(entry)
  local chunks = {}

  table.insert(chunks, { vim.fn.strftime("%c", entry.last_updated), "Comment" })

  if entry.group_name and #entry.group_name > 0 then
    table.insert(chunks, { entry.group_name, "Special" })
  else
    table.insert(chunks, { " ", "MsgArea" })
  end

  table.insert(chunks, { " | ", "Comment" })

  if entry.annote and #entry.annote > 0 then
    table.insert(chunks, { entry.annote, entry.style })
  else
    table.insert(chunks, { " ", "MsgArea" })
  end

  table.insert(chunks, { entry.message, "MsgArea" })

  return chunks
end

local notification_previewer = function()
  return previewers.new_buffer_previewer({
    title = "Notification Details",
    define_preview = function(self, entry, _)
      local notification_entry = entry.value
      local bufnr = self.state.bufnr

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

      local lines = {
        "Timestamp: " .. vim.fn.strftime("%c", notification_entry.last_updated),
        "Group: " .. (notification_entry.group_name or ""),
        "Annotation: " .. (notification_entry.annote or ""),
        "Style: " .. (notification_entry.style or ""),
        "",
        "Message:",
        "--------",
        "",
      }

      local message_lines = vim.split(notification_entry.message, "\n")
      for _, line in ipairs(message_lines) do
        table.insert(lines, line)
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")

      local ns_id = vim.api.nvim_create_namespace("fidget_preview")

      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Title", 0, 0, 10)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Title", 1, 0, 6)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Title", 2, 0, 11)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Title", 3, 0, 6)

      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Identifier", 0, 11, -1)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Special", 1, 7, -1)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "String", 2, 12, -1)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Comment", 3, 7, -1)

      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Title", 5, 0, -1)
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Comment", 6, 0, -1)

      if notification_entry.style then
        local hl_group = notification_entry.style
        for i = 8, #lines do
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, i - 1, 0, -1)
        end
      end
    end,
  })
end

local create_entry_maker = function(wrap)
  return function(entry)
    return {
      value = entry,
      display = function()
        local display_content = format_entry(entry)

        if wrap then
          local win_width = vim.api.nvim_win_get_width(0) - 10
          local msg = entry.message

          if #msg > win_width then
            msg = msg:sub(1, win_width - 3) .. "..."
          end

          display_content[#display_content] = { msg, "MsgArea" }
        end

        return entry_display.create({
          separator = " ",
          items = {
            {},
            {},
            {},
            { width = 2 },
            { remaining = true },
          },
        })(display_content)
      end,
      ordinal = entry.message,
    }
  end
end

local fidget_picker = function(opts)
  opts = opts or {}

  local default_config = {
    wrap_text = false,
    use_previewer = true,
  }

  local config = vim.tbl_deep_extend("force", default_config, opts)

  local picker_opts = {
    prompt_title = "Notifications",
    finder = finders.new_table({
      results = notification.get_history(),
      entry_maker = create_entry_maker(config.wrap_text),
    }),
    sorter = conf.generic_sorter(opts),
  }

  if config.use_previewer then
    picker_opts.previewer = notification_previewer()
  end

  picker_opts.attach_mappings = function(prompt_bufnr, _)
    actions.select_default:replace(function()
      actions.close(prompt_bufnr)

      local selected = action_state.get_selected_entry()
      if not selected then
        return
      end

      vim.api.nvim_echo(format_entry(selected.value), false, {})
    end)

    actions.select_horizontal:replace(function()
      actions.close(prompt_bufnr)
    end)

    actions.select_vertical:replace(function()
      actions.close(prompt_bufnr)
    end)

    actions.select_tab:replace(function()
      actions.close(prompt_bufnr)
    end)

    return true
  end

  pickers.new(opts, picker_opts):find()
end

return telescope.register_extension({
  setup = function(ext_config)
    _G.__fidget_telescope_config = ext_config or {}
  end,
  exports = {
    fidget = function(opts)
      local config = vim.tbl_deep_extend(
        "force",
        _G.__fidget_telescope_config or {},
        opts or {}
      )
      fidget_picker(config)
    end,
  },
})
