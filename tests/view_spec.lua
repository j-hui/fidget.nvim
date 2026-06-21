local eq = assert.are.same
local is_true = assert.is_true
local is_nil = assert.is_nil

describe("notification view cache", function()
  before_each(function()
    require("fidget").setup({ logger = { enable = false } })
  end)

  it("is_multigrid_ui returns a boolean", function()
    is_true(type(require("fidget.notification.view").is_multigrid_ui()) == "boolean")
  end)

  it("is_multigrid_ui caches and force-re-evaluates", function()
    local view = require("fidget.notification.view")
    local u1 = view.is_multigrid_ui()
    local u2 = view.is_multigrid_ui()
    eq(u1, u2)
    local u3 = view.is_multigrid_ui(true)
    is_true(type(u3) == "boolean")
  end)

  it("render_group_separator caches its return value", function()
    local view = require("fidget.notification.view")
    local sep1, w1 = view.render_group_separator()
    is_true(sep1 ~= nil)
    is_true(w1 > 0)
    local sep2, w2 = view.render_group_separator()
    eq(sep1, sep2)
    eq(w1, w2)
  end)

  it("render_group_header is stable across calls", function()
    local view = require("fidget.notification.view")
    local group = { config = { name = "test", icon = "x" }, items = {} }
    local h1, hw1 = view.render_group_header(vim.loop.now(), group)
    local h2, hw2 = view.render_group_header(vim.loop.now(), group)
    is_true(h1 ~= nil)
    eq(hw1, hw2)
  end)

  it("render with multiple groups uses separator cache", function()
    local view = require("fidget.notification.view")
    local groups = {
      { key = "g1", config = { name = "g1" }, items = { { message = "hello", content_key = "hello" } } },
      { key = "g2", config = { name = "g2" }, items = { { message = "world", content_key = "world" } } },
    }
    local lines, maxw = view.render(vim.loop.now(), groups)
    is_true(lines ~= nil)
    is_true(maxw > 0)
  end)
end)
