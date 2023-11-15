---@mod fidget.progress.handle Non-LSP progress messages
local handle = {}

local notification = require("fidget.notification")

local next_id = 0
local prefix = "fidget-progress-handle-"

local function next_token()
  next_id = next_id + 1
  return prefix .. tostring(next_id)
end

--- A handle for a progress message, reactive to changes
---@class ProgressHandle: ProgressMessage
---@field cancel fun(self: ProgressHandle) Cancel the task
---@field finish fun(self: ProgressHandle) Mark the task as complete
---@field report fun(self: ProgressHandle, msg: ProgressMessage|table<string,any>) Update one or more properties of the progress message
---@field private _raw ProgressMessage The internal progress message data
---@field private _proxy userdata A proxy object used to handle cleanup
local ProgressHandle = {}

function ProgressHandle.new(message)
  local progress = require("fidget.progress")

  local self = {}

  -- Use a proxy with __gc to handle cleanup, ensuring that we don't
  -- leak notifications if the user doesn't call finish() or cancel().
  self._proxy = newproxy(true)
  self._raw = message

  getmetatable(self._proxy).__gc = function()
    if not self._raw.done then
      self._raw.done = true
      notification.notify(progress.format_progress(self._raw))
    end
  end

  setmetatable(self, ProgressHandle)

  -- Load the notification config
  progress.load_config(self._raw)

  -- Initial update (for begin)
  notification.notify(progress.format_progress(self._raw))

  return self
end

function ProgressHandle:__newindex(k, v)
  if k == "token" then
    error("notification tokens cannot be modified")
  end
  self._raw[k] = v
  notification.notify(require("fidget.progress").format_progress(self._raw))
end

function ProgressHandle:__index(k)
  return ProgressHandle[k] or self._raw[k]
end

function ProgressHandle:report(props)
  if self._raw.done then
    return
  end
  props.token = nil
  for k, v in pairs(props) do
    self._raw[k] = v
  end
  notification.notify(require("fidget.progress").format_progress(self._raw))
end

function ProgressHandle:cancel()
  if self._raw.done then
    return
  end
  if self._raw.cancellable then
    self._raw.done = true
    notification.notify(require("fidget.progress").format_progress(self._raw))
  else
    error("attempted to cancel non-cancellable progress")
  end
end

function ProgressHandle:finish()
  if self._raw.done then
    return
  end
  self._raw.done = true
  if self._raw.percentage ~= nil then
    self._raw.percentage = 100
  end
  notification.notify(require("fidget.progress").format_progress(self._raw))
end

--- Create a new progress message, and return a handle to it for updating.
--- The handle is a reactive object, so you can update its properties and the
--- message will be updated accordingly. You can also use the `report` method to
--- update multiple properties at once.
---
--- Example:
---
--->lua
--- local progress = require("fidget.progress")
---
--- local handle = progress.handle.create({
---   title = "My Task",
---   message = "Doing something...",
---   lsp_client = { name = "my_fake_lsp" },
---   percentage = 0,
--- })
---
--- -- You can update properties directly and the
--- -- progress message will be updated accordingly
--- handle.message = "Doing something else..."
---
--- -- Or you can use the `report` method to bulk-update
--- -- properties.
--- handle:report({
---   title = "The task status changed"
---   message = "Doing another thing...",
---   percentage = 50,
--- })
---
--- -- You can also cancel the task (errors if not cancellable)
--- handle:cancel()
---
--- -- Or mark it as complete (updates percentage to 100 automatically)
--- handle:finish()
---<
---
---@param message ProgressMessage|table<string, any> The initial progress message
---@return ProgressHandle
---@nodiscard
function handle.create(message)
  message = message and vim.deepcopy(message) or {}

  -- Generate a unique token for this message
  message.token = next_token()

  -- Set required fields
  message.lsp_client = message.lsp_client or {
    name = "fidget",
  }
  if message.done == nil then
    message.done = false
  end

  -- Cancellable by default
  if message.cancellable == nil then
    message.cancellable = true
  end

  return ProgressHandle.new(message)
end

return handle
