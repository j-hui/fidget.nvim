local fidget = require("fidget")
local notif = require("fidget.notification")
local handle = require("fidget.progress.handle")

local eq = assert.are.same
local is_nil = assert.is_nil

describe("progress handle", function()
  before_each(function()
    require("fidget").setup({})
    notif.clear()
    notif.window.close()
  end)

  it("should create a handle", function()
    local h = handle.create({
      title = "test",
      message = "test message",
    })
    assert(h ~= nil)

    eq(h.title, "test")
    eq(h.message, "test message")
    eq(h.done, false)

    -- defaults
    eq(h.lsp_client, { name = "fidget" })
    eq(h.cancellable, true)
  end)

  it("should update when report() is called", function()
    local h = handle.create({
      title = "test",
      message = "test message",
    })
    h:report({
      message = "new message",
      percentage = 50,
    })
    eq(h.message, "new message")
    eq(h.percentage, 50)
  end)

  it("should complete when finish() is called", function()
    local h = handle.create({
      title = "test",
      message = "test message",
    })
    h:finish()
    eq(h.done, true)
    is_nil(h.percentage)
  end)

  it("should set percentage to 100 when complete", function()
    local h = handle.create({
      title = "test",
      message = "test message",
      percentage = 0,
    })
    eq(h.percentage, 0)
    eq(h.done, false)
    h:report({
      percentage = 50,
    })
    eq(h.percentage, 50)
    eq(h.done, false)
    h:finish()
    eq(h.percentage, 100)
    eq(h.done, true)
  end)

  it("should *not* set percentage when cancel() is called", function()
    local h = handle.create({
      title = "test",
      message = "test message",
      percentage = 0,
    })
    h:report({
      percentage = 40,
    })
    h:cancel()
    eq(h.done, true)
    eq(h.percentage, 40)
  end)

  it("should *not* initialize percentage when not provided", function()
    local h = handle.create({
      title = "test",
      message = "test message",
    })
    eq(h.percentage, nil)
    eq(h.done, false)
    h:finish()
    eq(h.percentage, nil)
    eq(h.done, true)
  end)
end)
