#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles
CHANGES="$(git -C "$DIR" status --short 2>/dev/null || true)"
if [ -n "$CHANGES" ]; then
  echo "Applying these local changes:"
  echo "$CHANGES" | sed 's/^/    /'
else
  echo "No local changes; re-applying the current config."
fi
exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac
