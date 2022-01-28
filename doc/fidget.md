---
project: fidget.nvim
vimversion: Neovim v0.6.0
toc: true
description: Standalone UI for nvim-lsp progress
---

# fidget.nvim

## Installation

Install this plugin using your favorite plugin manager.
For example, using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'j-hui/fidget.nvim'
```

Make sure the plugin installed (e.g., run `:PlugInstall` if using vim-plug).
After the plugin is loaded (e.g., after `plug#end()` for vim-plug), call its
`setup` function (in Lua):

```lua
require"fidget".setup{}
```

`setup` takes a table of [options](#options) as its parameter, used to
configure the plugin.

## Concepts

This section summarizes the vocabulary used by this plugin and its
documentation to describe relevant concepts, and clarifies the relationship
between those concepts.

A **task** is a particular job that is completed in the background. Examples
include indexing a project, linting a module, or formatting a file.

A task's **message** describes its status.

A **fidget** (a pun on "widget") represents an entity that performs
a collection of tasks. For now, this plugin only supports fidgets that
represent LSP servers. A fidget may perform multiple tasks concurrently.

A fidget's **spinner** is an icon shown next next to the fidget's name, for
purely aesthetic purposes.

This plugin displays the progress of tasks grouped by fidget. For example, if
there are two fidgets, `fidgetA` and `fidgetB`, with tasks `taskA1`, `taskA2`
and `taskB1`, `taskB2`, respectively, they might be displayed as follows:

```
fidgetA ...
Started [taskA1]
Ongoing [taskA2]
fidgetB ...
Completed [taskB1]
Ongoing [taskB2]
```

Each fidget's spinner is `...`; the tasks' messages are `Started`, `Ongoing`,
and `Completed`.

## Options

The following table shows the default options for this plugin:

```lua
{
  text = {
    spinner = "pipe",         -- animation shown when tasks are ongoing
    done = "✔",               -- character shown when all tasks are complete
    commenced = "Started",    -- message shown when task starts
    completed = "Completed",  -- message shown when task completes
  },
  align = {
    bottom = true,            -- align fidgets along bottom edge of buffer
    right = true,             -- align fidgets along right edge of buffer
  },
  timer = {
    spinner_rate = 125,       -- frame rate of spinner animation, in ms
    fidget_decay = 2000,      -- how long to keep around empty fidget, in ms
    task_decay = 1000,        -- how long to keep around completed task, in ms
  },
  fmt = {
    leftpad = true,           -- right-justify text in fidget box
    stack_upwards = true,     -- list of tasks grows upwards
    fidget =                  -- function to format fidget title
      function(fidget_name, spinner)
        return string.format("%s %s", spinner, fidget_name)
      end,
    task =                    -- function to format each task line
      function(task_name, message, percentage)
        return string.format(
          "%s%s [%s]",
          message,
          percentage and string.format(" (%s%%)", percentage) or "",
          task_name
        )
      end,
  },
  debug = {
    logging = false,          -- whether to enable logging, for debugging
  },
}
```

#### text.spinner

Animation shown in fidget title when its tasks are ongoing. Can either be the
name of one of the predefined [fidet-spinners](#fidget-spinners), or an array
of strings representing each frame of the animation.

Type: `string` or `[string]` (default: `"pipe"`)

#### text.done

Text shown in fidget title when all its tasks are completed, i.e., it has no
more tasks.

Type: `string` (default: `"✔"`)

#### text.commenced

Message shown when a task starts.

Type: `string` (default: `"Started"`)

#### text.completed

Message shown when a task completes.

Type: `string` (default: `"Completed"`)

#### align.bottom

Whether to align fidgets along the bottom edge of each buffer.

Type: `bool` (default: `true`)

#### align.right

Whether to align fidgets along the right edge of each buffer. Setting this to
`false` is not recommended, since that will lead to the fidget text being
regularly overlaid on top of buffer text (which is supported but unsightly).

Type: `bool` (default: `true`)

#### timer.spinner_rate

Duration of each frame of the spinner animation, in ms. Set to `0` to only use
the first frame of the spinner animation.

Type: `int` (default: `125`)

#### timer.fidget_decay

How long to continue showing a fidget after all its tasks are completed, in ms.
Set to `0` to clear each fidget as soon as all its tasks are completed; set
to any negative number to keep it around indefinitely (not recommended).

Type: `int` (default: `2000`)

#### timer.task_decay

How long to continue showing a task after it is complete, in ms. Set to `0` to
clear each task as soon as it is completed; set to any negative number to keep
it around until its fidget is cleared.

Type: `int` (default: `1000`)

#### fmt.leftpad

Whether to right-justify the text in a fidget box by left-padding it with
spaces. Recommended when [align.right](#align.right) is `true`.

Type: `bool` (default: `true`)

#### fmt.stack_upwards

Whether the list of tasks should grow upward in a fidget box. With this set to
`true`, fidget titles tend to jump around less.

Type: `bool` (default: `true`)

#### fmt.fidget

Function used to format the title of a fidget. Given two arguments: the name
of the fidget, and the current frame of the spinner. Returns the formatted
fidget title.

Type: `(string, string) -> string` (default: something sane)

#### fmt.task

Function used to format the status of each task. Given three arguments:
the name of the task, its message, and its progress as a percentage. Returns
the formatted task status.

Type: `(string, string, string) -> string` (default: something sane)

#### debug.logging

Whether to enable logging, for debugging. The log is written to
`~/.local/share/fidget.nvim.log`.

Type: `bool` (default: `false`)

## Highlights

This plugin uses the following highlights to display the fidgets, and can be
overridden to customize how fidgets look.

For example, to make the `FidgetTitle` blue, add the following to your .vimrc:

```vim
highlight FidgetTitle ctermfg=110 guifg=#6cb6eb
```

Or to [link](hi-link) it to the `Variable` highlight group:

```vim
highlight link FidgetTitle Variable
```

#### FidgetTitle

Highlight used for the title of a fidget.

Default: linked to [hl-Title](hl-Title)

#### FidgetTask

Highlight used for the body (the tasks) of a fidget.

Default: linked to [hl-LineNr](hl-LineNr)

## Spinners

The [text.spinner](#fidget-text.spinner) option recognizes the following
spinner pattern names:

```
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

See <lua/fidget/spinners.lua> of this plugin's source code to see how each
animation is defined.

## Troubleshooting

If in doubt, file an issue on <https://github.com/j-hui/fidget.nvim/issues>.

### I set up this plugin but nothing appears!

This plugin automatically installs its progress handler, but that may be
overwritten by other plugins by the time you arrive at the text buffer.
For example, if you also use
[nvim-lua/lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim),
its `register_progress` function will overwrite Fidget's progress handler.

You can check whether Fidget's progress handler is correctly installed using
`is_installed`. For example, to do this interactively, run the following Vim
command:

```vim
:lua print(require"fidget".is_installed())
```

If it isn't installed, make sure that it works by manually calling `setup`,
e.g.,:

```vim
:lua require"fidget".setup{}
```

If that works, then you need to make sure other plugins aren't clashing with
this one, or at least call Fidget's `setup` function after the other plugins
are done setting up.

## Acknowledgements

This plugin takes inspiration and borrows code from
[arkav/lualine-lsp-progress](https://github.com/arkav/lualine-lsp-progress).

[fidget-spinner](#fidget-spinner) designs adapted from the npm package
[sindresorhus/cli-spinners](https://github.com/sindresorhus/cli-spinners).
