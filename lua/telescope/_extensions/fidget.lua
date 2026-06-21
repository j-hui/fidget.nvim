local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local notification = require("fidget.notification")
local pickers = require("telescope.pickers")
local telescope = require("telescope")
local previewers = require("telescope.previewers")
local buf = require("fidget.buf")

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

  table.insert(chunks, { entry.message:match("([^\n]*)"), "MsgArea" })

  return chunks
end

local function previewer()
  return previewers.new_buffer_previewer({
    title = "Notification Details",
    define_preview = function(self, entry)
      local data = entry.value
      local bufnr = self.state.bufnr

      buf
        .new_builder()
        :write(string.format(" %s ", data.annote or " "), data.style)
        :write(vim.fn.strftime("%c", data.last_updated), "Comment")
        :space(1)
        :write(data.group_name or "", "Special")
        :separator()
        :write(data.message or "")
        :render(bufnr)
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

local default_config = {
  wrap_text = false,
  previewer = true,
}

local fidget_picker = function(opts)
  opts = vim.tbl_extend("force", default_config, opts or {})

  local picker_opts = {
    prompt_title = "Notifications",
    finder = finders.new_table({
      results = notification.get_history(),
      entry_maker = create_entry_maker(opts.wrap_text),
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewer(),
  }

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
    default_config = vim.tbl_extend("force", default_config, ext_config or {})
  end,
  exports = {
    fidget = fidget_picker,
  },
})
