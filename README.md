# fidget.nvim

Standalone UI for nvim-lsp progress. Eye candy for the impatient.

![fidget.nvim demo](https://github.com/j-hui/fidget.nvim/blob/media/gifs/fidget-demo-rust-analyzer.gif?raw=true)

## Why?

The goals of this plugin are:

- to provide a UI for nvim-lsp's [progress][lsp-progress] handler.
- to be easy to configure
- to stay out of the way of other plugins (in particular status lines)

The language server protocol (LSP) defines an [endpoint][lsp-progress] for
servers to report their progress while performing work.
This endpoint is supported by Neovim's builtin LSP client, but only a handful
of plugins (that I'm aware of) make use of this feature.
Those that do typically report progress in the status line, where space is at
a premium and the layout is not well-suited to display the progress of
concurrent tasks coming from multiple LSP servers.
This approach also made status line configuration more complicated.

I wanted be able to see the progress reported by LSP servers without involving
the status line.
Who doesn't love a little bit of eye candy?

[lsp-progress]: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#progress

## Requirements

- Neovim v0.7.0+
- [nvim-lsp](https://github.com/neovim/nvim-lspconfig)
- An LSP server that implements LSP's [progress][lsp-progress] endpoint

Having a working nvim-lsp setup is not technically necessary to _setup_ the
plugin, but it won't do anything without a source of progress notifications.

For an up-to-date list of LSP servers this plugin is known to work with, see
[this pinned issue](https://github.com/j-hui/fidget.nvim/issues/17).

## Quickstart

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

See the [documentation](doc/fidget.md) for configuration options.

## Acknowledgements and Alternatives

This plugin takes inspiration and borrows code from
[arkav/lualine-lsp-progress](https://github.com/arkav/lualine-lsp-progress).

Fidget spinner designs were adapted from the npm package
[sindresorhus/cli-spinners](https://github.com/sindresorhus/cli-spinners).

[nvim-lua/lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) also
supports showing progress text, though it requires some configuration to
integrate that into their status line.

[neoclide/coc.nvim](https://github.com/neoclide/coc.nvim) provides a nice LSP
progress UI in the status line, which first inspired my desire to have this
feature for nvim-lsp.
