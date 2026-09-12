#!/usr/bin/env bash
# Takes a fresh Mac from nothing to a built nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
# Usage: ./bootstrap.sh [--debug]
set -euo pipefail

trap 'echo "!!! bootstrap.sh failed (exit $?). Re-run with ./bootstrap.sh --debug for details." >&2' ERR
if [ "${1:-}" = "--debug" ]; then
  set -x
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Strap guards: run as yourself (not root) and require admin for sudo.
[ "$(whoami)" = "root" ] && { echo "!!! Run bootstrap as yourself, not root." >&2; exit 1; }
groups | grep -q -E "\b(admin)\b" || { echo "!!! Add $(whoami) to the admin group first." >&2; exit 1; }
# Prevent sleeping during the long first switch while on AC power.
caffeinate -s -w $$ &

echo "==> Step 0: fresh-Mac prerequisites (Strap-style checks)"
# Xcode Command Line Tools provide git/clang; Strap installs them explicitly.
if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  echo "    Xcode Command Line Tools not found."
  echo "    Run 'xcode-select --install' first, then re-run ./bootstrap.sh."
  exit 1
fi
# FileVault cannot be enabled declaratively; warn like Strap instead of forcing it.
if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
  echo "    FileVault is on, nothing to do."
else
  echo "    WARNING: FileVault is off."
  echo "    Enable it in System Settings > Privacy and Security > FileVault,"
  echo "    or run 'sudo fdesetup enable -user \"$(whoami)\"'. Continuing anyway."
fi

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: personalize the configured username"
# Do this before any sudo call: sudo resets $USER to root, so whoami has to
# run as the real interactive user first.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: review the plan (no system changes made yet)"
echo "    user: \"$REAL_USER\" | host label: mac | arch: $(uname -m)"
echo "    This applies system settings, Nix packages, and shell configs."
echo "    Homebrew cleanup is \"zap\": anything installed but NOT declared in"
echo "    configuration.nix will be REMOVED. Nix-provided replacements live in home.nix."
if command -v brew >/dev/null 2>&1; then
  DECLARED_BREWS="$(nix eval --json "$DIR#darwinConfigurations.mac.config.homebrew.brews" 2>/dev/null || echo '[]')"
  DECLARED_CASKS="$(nix eval --json "$DIR#darwinConfigurations.mac.config.homebrew.casks" 2>/dev/null || echo '[]')"
  DOOMED_BREWS="$(brew list --installed-on-request 2>/dev/null | BREWS_JSON="$DECLARED_BREWS" python3 -c "
import json, os, sys
data = json.loads(os.environ.get('BREWS_JSON', '[]'))
declared = set(x.get('name') if isinstance(x, dict) else x for x in data)
print(' '.join(sorted(n for n in (l.strip() for l in sys.stdin) if n and n not in declared)) or '(none)')")"
  DOOMED_CASKS="$(brew list --cask 2>/dev/null | CASKS_JSON="$DECLARED_CASKS" python3 -c "
import json, os, sys
data = json.loads(os.environ.get('CASKS_JSON', '[]'))
declared = set(x.get('name') if isinstance(x, dict) else x for x in data)
print(' '.join(sorted(n for n in (l.strip() for l in sys.stdin) if n and n not in declared)) or '(none)')")"
  echo "    Brews to be removed: $DOOMED_BREWS"
  echo "    Casks to be removed: $DOOMED_CASKS"
else
  echo "    Homebrew is not installed yet, so nothing will be removed."
fi
read -r -p "    Apply the switch now? [y/N] " GO
if [ "$GO" != "y" ] && [ "$GO" != "Y" ]; then
  echo "    Cancelled before any system change. Re-run when ready."
  exit 0
fi

echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
# darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
# from the flake this once. After this, rebuild.sh works normally.
# This fetches the darwin-rebuild tool from the nix-darwin-26.05 release branch,
# not the exact flake.lock revision. The system config it applies is still pinned
# by this repo's flake.lock.
# sudo resets PATH to a secure default that excludes /nix/.../bin, so a
# freshly installed `nix` would not be found under sudo even though it's
# on PATH here. Resolve the absolute path first and invoke that instead.
NIX_BIN="$(command -v nix)"
# "mac" is the flake host label - if you renamed it, change it in flake.nix
# and rebuild.sh too.
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
# If this still fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.

echo "==> Done. Your system is now managed."
echo "    Open a NEW shell, then verify:"
echo "      git config user.email         # kynjal26 noreply (~/work/ gives KingJune28)"
echo "      gh auth login                 # once per GitHub account; tokens stay in your keyring"
echo "      nvim                          # installs the theme on first launch (needs network once)"
echo "    Daily use: ./rebuild.sh (or the 'rebuild' alias in new shells)."
