--- This module contains type definitions used by the notifications subsystem.
--- It does not define any actual variables and should not be imported; it
--- exists only in service of the almighty sumneko LSP.
_ = nil

--- Used to distinguish one notification group or item from others.
---@alias Key any

--- Vim log levels e.g., vim.log.levels.INFO. (DEBUG and TRACE are not supported.)
---@alias Level number

--- Something that can be displayed. If callable, it is invoked every render cycle
--- with the item list; useful for rendering animations and other dynamic content.
---@alias Display string | fun(now: number, items: NotificationItem[]): string

---@class NotificationConfig
---@field name              Display?  name of the group; if nil, tostring(key) is used as name
---@field icon              Display?  icon of the group; if nil, no icon is used
---@field icon_on_left      boolean?  if true, icon is rendered on the left instead of right
---@field annote_separator  string?   separator between message from annote; defaults to " "
---@field ttl               number    how long after a notification item should exist
---@field name_style        Style     style used to highlight group name
---@field icon_style        Style?    style used to highlight icon; if nil, use name_style
---@field annote_style      Style     default style used to highlight item annotes
---@field info_style        Style?    style used to highlight info item annotes
---@field hint_style        Style?    style used to highlight hint item annotes
---@field warn_style        Style?    style used to highlight warn item annotes
---@field error_style       Style?    style used to highlight error item annotes

---@class NotificationOptions
---@field key           Key?      replace existing notification item of the same key
---@field group         Key?      group that this notification item belongs to
---@field annote        string?   optional single-line title that accompanies the message
---@field hidden        boolean   whether this item should be shown
---@field ttl           number?   how long after a notification item should exist; pass 0 to use default value
---@field data          any?      arbitrary data attached to notification item

---@class NotificationGroup
---@field key           Key                 used to distinguish this group from others
---@field config        NotificationConfig  configuration for this group
---@field items         NotificationItem[]  items displayed in the group

---@class NotificationItem
---@field key         Key       used to distinguish this item from others
---@field message     string    displayed message for the item
---@field annote      string?   optional title that accompanies the message
---@field style       Style     style used to render the annote/title, if any
---@field hidden      boolean   whether this item should be shown
---@field expires_at  number    what time this item should be removed; math.huge means never
---@field data        any?      arbitrary data attached to notification item

---@class NotificationView
---@field width       number                    the maximum width of any line
---@field lines       string[]                  text to show in the notification
---@field highlights  NotificationHighlight[]   buf_add_highlight() params, applied in order

---@class NotificationHighlight
---@field hl_group    Style     what highlight group to add
---@field line        number    (0-indexed) line number to add highlight
---@field col_start   number    (byte-indexed) column to start highlight
---@field col_end     number    (byte-indexed) column to end highlight

---@alias Style string
