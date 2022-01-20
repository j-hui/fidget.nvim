local api = vim.api
local log = require"fidget.log"

local fidget = {}
local clients = {}
local options = {
  message = {
    commenced = "Started",
    completed = "Completed",
  },
  rightpad = true,
  spinner = { "▙", "▛", "▜", "▟" },
  fmt = function(spinner, client, msg, percentage)
    return string.format(
      "%s %s[%s] %s",
      msg,
      percentage and string.format("(%s%%) ", percentage) or "",
      client,
      spinner
    )
  end,
    timer = {
      progress_enddelay = 500,
      spinner = 500,
      lsp_client_name_enddelay = 1000,
    },
}

local _widget = { winid = nil, bufid = nil }
local function get_widget(width, height, col, row, anchor)
  if _widget.bufid == nil or not api.nvim_buf_is_valid(_widget.bufid) then
    _widget.bufid = api.nvim_create_buf(false, true)
  end
  if _widget.winid == nil or not api.nvim_win_is_valid(_widget.winid) then
    _widget.winid = api.nvim_open_win(_widget.bufid, false, {
      relative = "win",
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
      focusable = false,
      style = "minimal",
      noautocmd = true,
    })
  else
    api.nvim_win_set_config(_widget.winid, {
      win = api.nvim_get_current_win(),
      relative = "win",
      width = width,
      height = height,
      row = row,
      col = col,
      anchor = anchor,
    })
  end
  return _widget.bufid
end

function fidget.recho(s)
  local buf = get_widget(
    #s,
    1,
    api.nvim_win_get_width(0),
    api.nvim_win_get_height(0),
    "SE"
  )
  api.nvim_buf_set_lines(buf, 0, 0, false, { s })
end

local function handle_progress(_, msg, info)
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
  -- https://github.com/arkav/lualine-lsp-progress/blob/master/lua/lualine/components/lsp_progress.lua#L73

  -- TODO: copy from ts context: https://github.com/romgrk/nvim-treesitter-context/blob/b7d7aba81683c1cd76141e090ff335bb55332cba/lua/treesitter-context.lua#L269

  local key = msg.token
  local val = msg.value
  local client_key = tostring(info.client_id)

  if not key then
    return
  end

  -- Create entry if missing
  if clients[client_key] == nil then
    clients[client_key] = {
      progress = {},
      name = vim.lsp.get_client_by_id(info.client_id).name,
    }
  end
  local progress_group = clients[client_key].progress
  if progress_group[key] == nil then
    progress_group[key] = { title = nil, message = nil, percentage = nil }
  end

  local progress = progress_group[key]

  -- Update progress state
  if val.kind == "begin" then
    progress.title = val.title
    progress.message = options.message.commenced
  elseif val.kind == "report" then
    if val.percentage then
      progress.percentage = val.percentage
    end
    if val.message then
      progress.message = val.message
    end
  elseif val.kind == "end" then
    if progress.percentage then
      progress.percentage = "100"
    end
    progress.message = options.message.completed
  end

  log.debug(vim.inspect(clients))

  fidget.recho(progress.message)
  -- print(progress.message)
  -- vim.defer_fn(function()
  --   if self.clients[client_key] then
  --     self.clients[client_key].progress[key] = nil
  --   end
  --   vim.defer_fn(function()
  --     local has_items = false
  --     if self.clients[client_key] and self.clients[client_key].progress then
  --       for _, _ in pairs(self.clients[client_key].progress) do
  --         has_items = 1
  --         break
  --       end
  --     end
  --     if has_items == false then
  --       self.clients[client_key] = nil
  --     end
  --   end, self.options.timer.lsp_client_name_enddelay)
  -- end, self.options.timer.progress_enddelay)
end

function fidget.setup(opts)
  opts = opts or {}
  options = vim.tbl_deep_extend("force", options, opts)
  vim.lsp.handlers["$/progress"] = handle_progress
end

return fidget
