---@class fidget.buf
local M = {}

---@class fidget.buf.BuilderOpts

---@class fidget.buf.Builder
---@field lines string[]
---@field row number
---@field col number
---@field opts fidget.buf.BuilderOpts
---@field hls table[]
local Builder = {}
Builder.__index = Builder

---Write content
---@param text string
---@param hl_group? string | number | vim.api.keyset.highlight
---@return fidget.buf.Builder
function Builder:write(text, hl_group)
  local row, col = self.row, self.col
  local parts = vim.split(text, "\n", { plain = true })

  for i, part in ipairs(parts) do
    local line = self.lines[row + 1] or ""
    self.lines[row + 1] = line .. part
    col = col + #part

    -- new line
    if i < #parts then
      row = row + 1
      col = 0
    end
  end

  if hl_group then
    table.insert(self.hls, {
      row = self.row,
      col = self.col,
      end_row = row,
      end_col = col,
      hl_group = hl_group,
    })
  end

  self.row = row
  self.col = col

  return self
end

---Write new line.
---@param n? number
---@return fidget.buf.Builder
function Builder:ln(n)
  n = n or 1
  for _ = 1, n do
    -- check first line is empty, because row is 0-base, self.lines is a 1-base array
    if self.row == 0 and self.lines[1] == nil then
      self.lines[1] = ""
    end

    self.row = self.row + 1
    self.lines[self.row + 1] = ""
  end
  self.col = 0

  return self
end

---Write {n} spaces
---@param n? number
---@return fidget.buf.Builder
function Builder:space(n)
  return self:write(string.rep(" ", n or 1))
end

function Builder:separator(sep, hl_group)
  sep = sep or require("config.icons").icons.sep
  hl_group = hl_group or "WinSeparator"

  if self.col ~= 0 then
    -- new line
    self:ln()
  end
  local row = self.row

  table.insert(self.hls, function(bufnr, ns)
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      virt_text = { { sep:rep(200), hl_group } },
      virt_text_pos = "overlay",
      virt_text_win_col = 0,
    })
  end)

  self:ln()

  return self
end

---Render content, set extmarks.
---@param bufnr number
---@param ns? number namespace
function Builder:render(bufnr, ns)
  if #self.lines == 0 then
    return
  end

  ns = ns
    or vim.api.nvim_create_namespace(string.format("content_builder_%s", bufnr))

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, self.lines)

  local id = 0
  local set_extmark = function(hl)
    if type(hl) == "function" then
      hl(bufnr, ns)

      return
    end

    local hl_name = hl.hl_group
    if type(hl_name) == "table" then
      hl_name = vim.api.nvim_set_hl(
        ns,
        string.format("NS_%s_HL_%s", ns, id),
        hl.hl_group
      )
      id = id + 1
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns, hl.row, hl.col, {
      end_row = hl.end_row,
      end_col = hl.end_col,
      hl_group = hl_name,
    })
  end

  for _, hl in ipairs(self.hls) do
    set_extmark(hl)
  end
end

---Create a buf content builder.
---@param opts? fidget.buf.BuilderOpts
---@return fidget.buf.Builder
function M.new_builder(opts)
  return setmetatable({
    row = 0,
    col = 0,
    lines = {},
    hls = {},
    opts = opts,
  }, Builder)
end

return M
