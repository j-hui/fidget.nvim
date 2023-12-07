#!/usr/bin/env sh

set -e

cd "$(git rev-parse --show-toplevel)" || exit 2

case "$(uname)" in
  Darwin)
    # Let's hope rosetta is installed if this is an Apple Silicon chip
    curl -Lq https://github.com/numToStr/lemmy-help/releases/latest/download/lemmy-help-x86_64-apple-darwin.tar.gz | tar xz
    ;;
  Linux)
    curl -Lq https://github.com/numToStr/lemmy-help/releases/latest/download/lemmy-help-x86_64-unknown-linux-gnu.tar.gz | tar xz
    ;;
  *)
    echo "Unknown OS. Exiting."
    exit 1
    ;;
esac

./lemmy-help -f -a -c -t \
  lua/fidget.lua \
  lua/fidget/notification.lua \
  lua/fidget/progress.lua \
  lua/fidget/progress/lsp.lua \
  lua/fidget/progress/handle.lua \
  lua/fidget/spinner.lua \
  > doc/fidget-api.txt

rm lemmy-help
