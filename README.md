<!-- panvimdoc-ignore-start -->

# 💫 Fidget

[![Docs](https://github.com/j-hui/fidget.nvim/actions/workflows/docs.yaml/badge.svg)](doc/fidget.txt)
[![LuaRocks](https://img.shields.io/luarocks/v/j-hui/fidget.nvim?logo=lua&color=purple)](https://luarocks.org/modules/j-hui/fidget.nvim)

Extensible UI for Neovim notifications and LSP progress messages.

![fidget.nvim demo](https://github.com/j-hui/fidget.nvim/blob/media/gifs/fidget-demo-rust-analyzer.gif?raw=true)

<details>
  <summary>Demo setup</summary>

*Note that this demo may not always reflect the exact behavior of the latest release.*

This screen recording was taken as I opened a Rust file I'm working on,
triggering `rust-analyzer` to send me some LSP progress messages.

As those messages are ongoing, I trigger some notifications with the following:

```lua
local fidget = require("fidget")

vim.keymap.set("n", "A", function()
  fidget.notify("This is from fidget.notify().")
end)

vim.keymap.set("n", "B", function()
  fidget.notify("This is also from fidget.notify().", vim.log.levels.WARN)
end)

vim.keymap.set("n", "C", function()
  fidget.notify("fidget.notify() supports annotations...", nil, { annote = "MY NOTE", key = "foobar" })
end)

vim.keymap.set("n", "D", function()
  fidget.notify(nil, vim.log.levels.ERROR, { annote = "bottom text", key = "foobar" })
  fidget.notify("... and overwriting notifications.", vim.log.levels.WARN, { annote = "YOUR AD HERE" })
end)
```

(I use normal mode keymaps to avoid going into ex mode, which would pause Fidget
rendering and make the demo look glitchy...)

Visible elements:

-   Terminal + font: [Kitty](https://sw.kovidgoyal.net/kitty/) + [Comic Shanns Mono](https://github.com/shannpersand/comic-shanns)
-   Editor: [Neovim v0.9.4](https://github.com/neovim/neovim/tree/v0.9.4)
-   Theme: [catppuccin/nvim (mocha, dark)](https://github.com/catppuccin/nvim)
-   Status line: [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
-   Color columns: `:set colorcolumn=81,121,+1,+2` (sorry)
-   Scrollbar: [petertriho/nvim-scrollbar](https://github.com/petertriho/nvim-scrollbar)

</details>

### Why?

Fidget is an unintrusive window in the corner of your editor that manages
its own lifetime. Its goals are:

- to provide a UI for Neovim's [`$/progress`][lsp-progress] handler
- to provide a configurable [`vim.notify()`][vim-notify] backend
- to support basic ASCII animations (Fidget spinners!) to indicate signs of life
- to be easy to configure, sane to maintain, and fun to hack on

There's only so much information one can stash into the status line. Besides,
who doesn't love a little bit of terminal eye candy, as a treat?

[lsp-progress]: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#progress
[vim-notify]: https://neovim.io/doc/user/lua.html#vim.notify()

<!-- panvimdoc-ignore-end -->

## Getting Started

### Requirements

Fidget requires Neovim v0.8.0+.

If you would like to see progress notifications, you must have configured Neovim
with an LSP server that uses the [`$/progress`][lsp-progress] handler.
For an up-to-date list of LSP servers this plugin is known to work with, see
[this Wiki page](https://github.com/j-hui/fidget.nvim/wiki/Known-compatible-LSP-servers).

### Installation

Install this plugin using your favorite plugin manager.

See the [documentation](#options) for `setup()` options.

#### [Lazy](https://github.com/folke/lazy.nvim)

```lua
{
  "j-hui/fidget.nvim",
  opts = {
    -- options
  },
}
```

#### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'j-hui/fidget.nvim'

" Make sure the plugin is installed using :PlugInstall. Then, somewhere after plug#end():
lua <<EOF
require("fidget").setup {
  -- options
}
EOF
```

#### [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim)

```vim
:Rocks install fidget.nvim
```

### Versioning

Fidget is actively developed on the `main` branch, and may occasionally undergo
breaking changes.

If you would like to ensure configuration/API stability, you can pin your tag to
one of the [release tags](https://github.com/j-hui/fidget.nvim/releases/).

For instance, using [Lazy](https://github.com/folke/lazy.nvim):

```lua
{
  "j-hui/fidget.nvim",
  tag = "v1.0.0",
  opts = {
    -- options
  },
}
```

## Options

```lua
{
  -- Options related to LSP progress subsystem
  progress = {
    poll_rate = 0,                -- How and when to poll for progress messages
    suppress_on_insert = false,   -- Suppress new messages while in insert mode
    ignore_done_already = false,  -- Ignore new tasks that are already complete
    ignore_empty_message = false, -- Ignore new tasks that don't contain a message
    clear_on_detach =             -- Clear notification group when LSP server detaches
      function(client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client and client.name or nil
      end,
    notification_group =          -- How to get a progress message's notification group key
      function(msg) return msg.lsp_client.name end,
    ignore = {},                  -- List of LSP servers to ignore

    -- Options related to how LSP progress messages are displayed as notifications
    display = {
      render_limit = 16,          -- How many LSP messages to show at once
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

    -- Options related to Neovim's built-in LSP client
    lsp = {
      progress_ringbuf_size = 0,  -- Configure the nvim's LSP progress ring buffer size
    },
  },

  -- Options related to notification subsystem
  notification = {
    poll_rate = 10,               -- How frequently to update and render notifications
    filter = vim.log.levels.INFO, -- Minimum notifications level
    override_vim_notify = false,  -- Automatically override vim.notify() with Fidget
    configs =                     -- How to configure notification groups when instantiated
      { default = require("fidget.notification").default_config },

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
      align = "bottom",           -- How to align the notification window
      relative = "editor",        -- What the notification window position is relative to
    },
  },

  -- Options related to logging
  logger = {
    level = vim.log.levels.WARN,  -- Minimum logging level
    float_precision = 0.01,       -- Limit the number of decimals displayed for floats
    path =                        -- Where Fidget writes its logs to
      string.format("%s/fidget.nvim.log", vim.fn.stdpath("cache")),
  },
}
```

<!-- panvimdoc-ignore-start -->

For more details, see [fidget-option.txt](doc/fidget-option.txt).

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment For more details, see |fidget-option.txt|. -->

## Lua API

<!-- panvimdoc-ignore-start -->

Fidget has a Lua API, with [documentation](doc/fidget-api.txt) generated from
source code. You are encouraged to hack around with that.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment See |fidget-api.txt|. -->

## Highlights

Rather than defining its own highlights, Fidget uses built-in highlight groups
that are typically overridden by custom Vim color schemes. With any luck, these
will look reasonable when rendered, but the visual outcome will really depend
on what your color scheme decided to do with those highlight groups.

## Related Work

[rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify) is first and
foremost a `vim.notify()` backend, and it also supports
[LSP progress notifications](https://github.com/rcarriga/nvim-notify/wiki/Usage-Recipes#lsp-status-updates)
(with the integration seems to have been packaged up in
[mrded/nvim-lsp-notify](https://github.com/mrded/nvim-lsp-notify)).

[vigoux/notifier.nvim](https://github.com/vigoux/notifier.nvim) is
a `vim.notify()` backend that comes with first-class LSP notification support.

[neoclide/coc.nvim](https://github.com/neoclide/coc.nvim) provides a nice LSP
progress UI in the status line, which first inspired my desire to have this
feature for nvim-lsp.

[arkav/lualine-lsp-progress](https://github.com/arkav/lualine-lsp-progress) was
the original inspiration for Fidget, and funnels LSP progress messages into
[nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim).
I once borrowed some of its code (though much of that code has since been
rewritten).

[nvim-lua/lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) also
supports showing progress text, though it requires some configuration to
integrate that into their status line.

### Acknowledgements

Most of the Fidget spinner patterns were adapted from the npm package
[sindresorhus/cli-spinners](https://github.com/sindresorhus/cli-spinners).
