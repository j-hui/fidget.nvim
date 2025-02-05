local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local notification = require("fidget.notification")
local pickers = require("telescope.pickers")
local telescope = require("telescope")

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

local fidget_picker = function(opts)
  opts = opts or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      {},
      {},
      {},
      { width = 2 },
      { remaining = true },
    },
  })

  pickers.new(opts, {
    prompt_title = "Notifications",
    finder = finders.new_table({
      results = notification.get_history(),
      entry_maker = function(entry)
        return {
          value = entry,
          display = function()
            return displayer(format_entry(entry))
          end,
          ordinal = entry.message,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, _)
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
    end,
  }):find()
end

return telescope.register_extension({
  setup = function() end,
  exports = {
    fidget = function(opts)
      fidget_picker(opts)
    end,
  },
})
