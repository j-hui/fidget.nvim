#!/usr/bin/env sh

set -e

cd "$(git rev-parse --show-toplevel)" || exit 2
txt=doc/fidget-option.txt

if which luajit >/dev/null 2>&1; then
  lua=luajit
elif which nvim >/dev/null 2>&1; then
  lua="nvim -l"
else
  echo "Error: could not find Lua executable in PATH"
  exit 1
fi

cat << EOF > "$txt"
*fidget-option.txt*                                     Fidget setup() options

==============================================================================

This file contains detailed documentation about all the setup() options that
Fidget supports.

For general documentation, see |fidget.txt|.

For Fidget's Lua API documentation, see |fidget-api.txt|.

EOF

$lua scripts/build-options-docs.lua --strip 1 --tag fidget.option \
  lua/fidget.lua \
  lua/fidget/progress.lua \
  lua/fidget/progress/display.lua \
  lua/fidget/progress/lsp.lua \
  lua/fidget/notification.lua \
  lua/fidget/notification/view.lua \
  lua/fidget/notification/window.lua \
  lua/fidget/integration/nvim-tree.lua \
  lua/fidget/logger.lua \
  >> "$txt"

echo "vim:tw=78:ts=4:ft=help:norl:" >> "$txt"
