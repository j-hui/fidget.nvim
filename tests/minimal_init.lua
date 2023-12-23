local deps = {
  "nvim-lua/plenary.nvim",
}

local uv = vim.uv or vim.loop

local tmp = uv.os_tmpdir()
local base = tmp .. "/fidget-test/"

local waiting = 0

for _, dep in ipairs(deps) do
  local path = base .. dep:gsub("/", "-")
  local stat = vim.loop.fs_stat(path)
  if stat == nil or stat.type ~= "directory" then
    vim.fn.mkdir(path, "p")
    waiting = waiting + 1
    uv.spawn("git", {
      args = { "clone", "https://github.com/" .. dep, path },
    }, function()
      waiting = waiting - 1
    end)
  end
  vim.opt.rtp:prepend(path)
end

vim.wait(10000, function()
  return waiting == 0
end)

vim.opt.rtp:prepend(uv.cwd())

require("plenary.busted")
