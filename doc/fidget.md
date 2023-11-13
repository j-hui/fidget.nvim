---
project: fidget
vimversion: Neovim v0.8.0
toc: true
description: Extensible UI for Neovim notifications and LSP progress messages
---

# Installation

Install this plugin using your favorite plugin manager.
Once installed, make sure to call its `setup()` function (in Lua), e.g.:

```lua
require("fidget").setup {
  -- options
}
```

`setup` takes a table of options as its parameter, used to configure the plugin.

# Options

The following table shows the default options for this plugin:

```lua
{
  -- Options related to LSP progress subsystem
  progress = {
    poll_rate = 5,                -- How frequently to poll for progress messages
    suppress_on_insert = false,   -- Suppress new messages while in insert mode
    ignore_done_already = false,  -- Ignore new tasks that are already complete
    notification_group =          -- How to get a progress message's notification group key
      function(msg) return msg.lsp_name end,
    ignore = {},                  -- List of LSP servers to ignore

    -- Options related to how LSP progress messages are displayed as notifications
    display = {
      done_ttl = 3,               -- How long a message should persist after completion
      done_icon = "✔",            -- Icon shown when all LSP progress tasks are complete
      done_style = "Constant",    -- Highlight group for completed LSP tasks
      progress_ttl = math.huge,   -- How long a message should persist when in progress
      progress_icon =             -- Icon shown when LSP progress tasks are in progress
        { pattern = "dots", period = 1 },
      progress_style =            -- Highlight group for in-progress LSP tasks
        "WarningMsg",
      group_style = "Title",      -- Highlight group for group name (LSP server name)
      icon_style = "Question",    -- Highlight group for group icons
      priority = 30,              -- Ordering priority for LSP notification group
      format_message =            -- How to format a progress message
        require("fidget.progress.display").default_format_message,
      format_annote =             -- How to format a progress annotation
        function(msg) return msg.title end,
      format_group_name =         -- How to format a progress notification group's name
        function(group) return tostring(group) end,
      overrides = {               -- Override options from the default notification config
        rust_analyzer = { name = "rust-analyzer" },
      },
    },
  },

  -- Options related to notification subsystem
  notification = {
    poll_rate = 10,               -- How frequently to poll and render notifications
    configs =                     -- How to configure notification groups when instantiated
      { default = M.default_config },
    override_vim_notify = false,  -- Automatically override vim.notify() with Fidget

    -- Options related to how notifications are rendered as text
    view = {
      stack_upwards = true,       -- Display notification items from bottom to top
      icon_separator = " ",       -- Separator between group name and icon
      group_separator = "---",    -- Separator between notification groups
      group_separator_hl =        -- Highlight group used for group separator
        "Comment",
    },

    -- Options related to the notification window and buffer
    window = {
      normal_hl = "Comment",      -- Base highlight group in the notification window
      winblend = 100,             -- Background color opacity in the notification window
      border = "none",            -- Border around the notification window
      zindex = 45,                -- Stacking priority of the notification window
      max_width = 0,              -- Maximum width of the notification window
      max_height = 0,             -- Maximum height of the notification window
      x_padding = 1,              -- Padding from right edge of window boundary
      y_padding = 0,              -- Padding from bottom edge of window boundary
      align_bottom = true,        -- Whether to bottom-align the notification window
    },
  },

  -- Options related to logging
  logger = {
    level = vim.log.levels.WARN,  -- Minimum logging level
    float_precision = 0.01,       -- Limit the number of decimals displayed for floats
  },
}
```

progress.poll_rate
: How frequently to poll for progress messages

Set to 0 to disable polling; you can still manually poll progress messages
by calling `fidget.progress.poll()`.

Measured in Hertz (frames per second).

Type: `number` (default: `5`)

progress.suppress_on_insert
: Suppress new messages while in insert mode

Note that progress messages for new tasks will be dropped, but existing
tasks will be processed to completion.

Type: `boolean` (default: `false`)

progress.ignore_done_already
: Ignore new tasks that are already complete

This is useful if you want to avoid excessively bouncy behavior, and only
seeing notifications for long-running tasks. Works best when combined with
a low `poll_rate`.

Type: `boolean` (default: `false`)

progress.notification_group
: How to get a progress message's notification group key

Set this to return a constant to group all LSP progress messages together,
e.g.,

```lua
notification_group = function(msg)
  -- N.B. you may also want to configure this group key ("lsp_progress")
  -- using progress.display.overrides or notification.configs
  return "lsp_progress"
end
```

Type: `fun(msg: ProgressMessage): NotificationKey` (default: `msg.lsp_name`)

progress.ignore
: List of LSP servers to ignore

Example:

```lua
ignore = { "rust_analyzer" }
```

Type: `NotificationKey[]` (default: `{}`)

progress.display.done_ttl
: How long a message should persist after completion

Set to `0` to use notification group config default, and `math.huge` to show
notification indefinitely (until overwritten).

Measured in seconds.

Type: `number` (default: `3`)

progress.display.done_icon
: Icon shown when all LSP progress tasks are complete

Type: `string | Manga` (default: `"✔"`)

progress.display.done_style
: Highlight group for completed LSP tasks

Type: `string` (default: `"Constant"`)

progress.display.progress_ttl
: How long a message should persist when in progress

Set to `0` to use notification group config default, and `math.huge` to show
notification indefinitely (until overwritten).

Measured in seconds.

Type: `number` (default: `math.huge`)

progress.display.progress_icon
: Icon shown when LSP progress tasks are in progress

Type: `string | Manga` (default: `{ pattern = "dots", period = 1 }`)

progress.display.progress_style
: Highlight group for in-progress LSP tasks

Type: `string` (default: `"WarningMsg"`)

progress.display.group_style
: Highlight group for group name (LSP server name)

Type: `string` (default: `"Title"`)

progress.display.icon_style
: Highlight group for group icons

Type: `string` (default: `"Question"`)

progress.display.priority
: Ordering priority for LSP notification group

Type: `number?` (default: `30`)

progress.display.format_message
: How to format a progress message

Example:

```lua
format_message = function(msg)
  if string.find(msg.title, "Indexing") then
    return nil -- Ignore "Indexing..." progress messages
  end
  if msg.message then
    return msg.message
  else
    return msg.done and "Completed" or "In progress..."
  end
end
```

Type: `fun(msg: ProgressMessage): string` (default: `fidget.display.default_format_message`)

where

```lua
function fidget.display.default_format_message(msg)
  local message = msg.message
  if not message then
    message = msg.done and "Completed" or "In progress..."
  end
  if msg.percentage ~= nil then
    message = string.format("%s (%.0f%%)", message, msg.percentage)
  end
  return message
end
```

progress.display.format_annote
: How to format a progress annotation

Type: `fun(msg: ProgressMessage): string` (default: `msg.title`)

progress.display.format_group_name
: How to format a progress notification group's name

Example:

```lua
format_group_name = function(group)
  return "lsp:" .. tostring(group)
end
```

Type: `fun(group: NotificationKey): NotificationDisplay` (default: `tostring`)

progress.display.overrides
: Override options from the default notification config

Keys of the table are each notification group's `key`.

Example:

```lua
overrides = {
  hls = {
    name = "Haskell Language Server",
    priority = 60,
    icon = fidget.progress.display.for_icon(fidget.spinner.animate("triangle", 3), "💯"),
  },
  rust_analyzer = {
    name = "Rust Analyzer",
    icon = fidget.progress.display.for_icon(fidget.spinner.animate("arrow", 2.5), "🦀"),
  },
}
```

Type: `{ [NotificationKey]: NotificationConfig }` (default: `{ rust_analyzer = { name = "rust-analyzer" } }`)

notification.poll_rate
: How frequently to poll and render notifications

Measured in Hertz (frames per second).

Type: `number` (default: `10`)

notification.override_vim_notify
: Automatically override vim.notify() with Fidget

Equivalent to the following:

```lua
fidget.setup({ --[[ options ]] })
vim.notify = fidget.notify
```

Type: `boolean` (default: `false`)

notification.configs
: How to configure notification groups when instantiated

A configuration with the key `"default"` should always be specified, and
is used as the fallback for notifications lacking a group key.

Type: `{ [NotificationKey]: NotificationConfig }` (default: `{ default = fidget.notification.default_config }`)

where

```lua
fidget.notification.default_config = {
  name = "Notifications",
  icon = "❰❰",
  ttl = 5,
  group_style = "Title",
  icon_style = "Special",
  annote_style = "Question",
  debug_style = "Comment",
  warn_style = "WarningMsg",
  error_style = "ErrorMsg",
  debug_annote = "DEBUG",
  info_annote = "INFO",
  warn_annote = "WARN",
  error_annote = "ERROR",
}
```

notification.view.stack_upwards
: Display notification items from bottom to top

Setting this to true tends to lead to more stable animations when the
window is bottom-aligned.

Type: `boolean` (default: `true`)

notification.view.icon_separator
: Separator between group name and icon

Must not contain any newlines. Set to `""` to remove the gap between names
and icons in _all_ notification groups.

Type: `string` (default: `" "`)

notification.view.group_separator
: Separator between notification groups

Must not contain any newlines. Set to `nil` to omit separator entirely.

Type: `string?` (default: `"---"`)

notification.view.group_separator_hl
: Highlight group used for group separator

Type: `string?` (default: `"Comment"`)

notification.window.normal_hl
: Base highlight group in the notification window

Used by any Fidget notification text that is not otherwise highlighted,
i.e., message text.

Note that we use this blanket highlight for all messages to avoid adding
separate highlights to each line (whose lengths may vary).

With `winblend` set to anything less than `100`, this will also affect the
background color in the notification box area (see `winblend` docs).

Type: `string` (default: `"Comment"`)

notification.window.winblend
: Background color opacity in the notification window

Note that the notification window is rectangular, so any cells covered by
that rectangular area is affected by the background color of `normal_hl`.
With `winblend` set to anything less than `100`, the background of
`normal_hl` will be blended with that of whatever is underneath,
including, e.g., a shaded `colorcolumn`, which is usually not desirable.

However, if you would like to display the notification window as its own
"boxed" area (especially if you are using a non-"none" `border`), you may
consider setting `winblend` to something less than `100`.

See also: options for [nvim_open_win()](<https://neovim.io/doc/user/api.html#nvim_open_win()>).

Type: `number` (default: `100`)

notification.window.border
: Border around the notification window

See also: options for [nvim_open_win()](<https://neovim.io/doc/user/api.html#nvim_open_win()>).

Type: `"none" | "single" | "double" | "rounded" | "solid" | "shadow" | string[]` (default: `"none"`)

notification.window.zindex
: Stacking priority of the notification window

Note that the default priority for Vim windows is 50.

See also: options for [nvim_open_win()](<https://neovim.io/doc/user/api.html#nvim_open_win()>).

Type: `number` (default: `45`)

notification.window.width
: Maximum width of the notification window

`0` means no maximum width.

Type: `integer` (default: `0`)

notification.window.height
: Maximum height of the notification window

`0` means no maximum height.

Type: `integer` (default: `0`)

notification.window.x_padding
: Padding from right edge of window boundary

Type: `integer` (default: `1`)

notification.window.y_padding
: Padding from bottom edge of window boundary

Type: `integer` (default: `0`)

notification.window.align_bottom
: Whether to bottom-align the notification window

Type: `boolean` (default: `true`)

logger.level
: Minimum logging level

Set to `vim.log.levels.OFF` to disable logging.

Type: `vim.log.levels` (default: `vim.log.levels.WARN`)

logger.float_precision
: Limit the number of decimals displayed for floats

Type: `number` (default: `0.01`)

<!-- ## Commands -->

<!-- TODO: write these -->

# Highlights

Rather than defining its own highlights, Fidget uses built-in highlight groups
that are typically overridden by custom Vim color schemes. With any luck, these
will look reasonable when rendered, but the visual outcome will really depend on
what your color scheme decided to do with those highlight groups.

<!-- TODO: little tutorial? to define your own highlights. -->

# Fidget Lua API

<!-- panvimdoc-ignore-start -->

Note that this Lua API documentation is not written for GitHub Markdown.
You might have a better experience reading it in Vim using `:h fidget.txt`.

<!-- panvimdoc-ignore-end -->

## Types

NotificationKey
: Determines the identity of notification items and groups.

Alias for `any` (non-`nil`) value.

NotificationLevel
: Second (`level`) parameter of `:h fidget-fidget.notification.notify()`.

Alias for `number | string`.

`string` indicates highlight group name; otherwise, `number` indicates
the `:h vim.log.levels` value (that will resolve to a highlight group as
determined by the `:h fidget-NotificationConfig`).

NotificationOptions
: Third (`opts`) parameter of `:h fidget-fidget.notification.notify()`.

Fields:

-   `key`: (`NotificationKey?`) Replace existing notification item of the same key
-   `group`: (`any?`) Group that this notification item belongs to
-   `annote`: (`string?`) Optional single-line title that accompanies the message
-   `hidden`: (`boolean?`) Whether this item should be shown
-   `ttl`: (`number?`) How long after a notification item should exist; pass 0 to use default value
-   `update_only`: (`boolean?`) If true, don't create new notification items
-   `data`: (`any?`) Arbitrary data attached to notification item, can be used by `:h fidget-NotificationDisplay` function

NotificationDisplay
: Displayed element in a `:h fidget-NotificationGroup`.

Alias for `string | fun(now: number, items: NotificationItem[]): string`.

If a callable `function`, it is invoked every render cycle with the items
list; useful for rendering animations and other dynamic content.

NotificationConfig
: Used to configure the behavior of notification groups.

See also: `:h fidget-notification.configs`.

Fields:

-   `name`: (`NotificationDisplay?`) Name of the group; if nil, tostring(key) is used as name
-   `icon`: (`NotificationDisplay?`) Icon of the group; if nil, no icon is used
-   `icon_on_left`: (`boolean?`) If true, icon is rendered on the left instead of right
-   `annote_separator`: (`string?`) Separator between message from annote; defaults to " "
-   `ttl`: (`number?`) How long a notification item should exist; defaults to 3
-   `group_style`: (`string?`) Style used to highlight group name; defaults to "Title"
-   `icon_style`: (`string?`) Style used to highlight icon; if nil, use group_style
-   `annote_style`: (`string?`) Default style used to highlight item annotes; defaults to "Question"
-   `debug_style`: (`string?`) Style used to highlight debug item annotes
-   `info_style`: (`string?`) Style used to highlight info item annotes
-   `warn_style`: (`string?`) style used to highlight warn item annotes
-   `error_style`: (`string?`) style used to highlight error item annotes
-   `debug_annote`: (`string?`) default annotation for debug items
-   `info_annote`: (`string?`) default annotation for info items
-   `warn_annote`: (`string?`) default annotation for warn items
-   `error_annote`: (`string?`) default annotation for error items
-   `priority`: (`number?`) order in which group should be displayed; defaults to 50

Anime
: A function that takes a timestamp and renders a frame (string).

Parameters:

- `now`: (`number`) The current timestamp (in seconds)

Returns:

- `string`: The contents of the frame right `now`

Manga
: A Manga is a table specifying an `:h fidget-Anime` to generate.

Fields:

-   `pattern`: (`string[] | string`) The name of pattern (see `:h fidget-Spinners`)
-   `period`: (`number`) How long one cycle of the animation should take, in seconds


## Functions

fidget.notify({msg}, {level}, {opts})
: Alias for `:h fidget.notifications.notify()`.

fidget.progress.suppress({suppress})
: Suppress consumption of progress messages.

Pass `true` as argument to turn on suppression, or `false` to turn it off.

If no argument is given, suppression state is toggled.

Parameters:

-   `{suppress}`: (`boolean?`) whether to suppress or toggle suppression

fidget.notification.notify({msg}, {level}, {opts})
: Send a notification.

Can be used to override `vim.notify()`, e.g.,

```lua
vim.notify = require("fidget.notifications").notify
```

Parameters:

-   `{msg}`: (`string?`) Content of the notification to show to the user.
-   `{level}`: (`NotificationLevel?`) One of the values from `:h vim.log.levels`, or the name of a highlight group.
-   `{opts}`: (`NotificationOptions?`) Notification options (see `:h fidget-NotificationOptions`).

fidget.notification.suppress({suppress})
: Suppress notification window.

Pass `true` as argument to turn on suppression, or `false` to turn it off.

If no argument is given, suppression state is toggled.

Parameters:

-   `{suppress}`: (`boolean?`) Whether to suppress or toggle suppression

fidget.spinner.animate({pattern}, {period})
: Generate an `:h fidget-Anime` function.

Parameters:

-   `{pattern}`: `(string[] | string)` Either an array of frames, or the name of a known pattern (see `:h fidget-Spinners`)
-   `{period}`: `(number)` How long one cycle of the animation should take, in seconds

Returns:

-   `(Anime)` Call this function to compute the frame at some given timestamp

<!-- TODO: usage example -->

## Spinners

The following spinner patterns are defined in `fidget.spinner.patterns`:

```
check
dots
dots_negative
dots_snake
dots_footsteps
dots_hop
line
pipe
dots_ellipsis
dots_scrolling
star
flip
hamburger
grow_vertical
grow_horizontal
noise
dots_bounce
triangle
arc
circle
square_corners
circle_quarters
circle_halves
dots_toggle
box_toggle
arrow
zip
bouncing_bar
bouncing_ball
clock
earth
moon
dots_pulse
meter
```

See <lua/fidget/spinner/patterns.lua> of the plugin source code to see each
animation frame of each pattern.

<!-- TODO: usage example -->


# Troubleshooting

If in doubt, file an issue on <https://github.com/j-hui/fidget.nvim/issues>.

Logs are written to `~/.cache/nvim/fidget.nvim.log`.

# Acknowledgements

[fidget-spinner](#spinner) designs adapted from the npm package
[sindresorhus/cli-spinners](https://github.com/sindresorhus/cli-spinners).
