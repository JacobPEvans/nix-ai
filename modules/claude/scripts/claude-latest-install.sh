#!/usr/bin/env bash
# claude-latest-install.sh - Install bleeding-edge Claude Code via the official installer
#
# Idempotent: if ~/.local/bin/claude already resolves to a native install
# (symlink into ~/.local/share/claude/versions/), exit 0 without touching anything.
# Otherwise, run the official Anthropic installer from claude.ai/install.sh.
#
# Claude Code self-updates thereafter via `claude update`. This script is only
# responsible for bootstrapping a missing install (and forced re-install on demand).
#
# Invoked by:
#   - LaunchAgent com.jacobpevans.claude-latest-install at login (RunAtLoad=true, no-op normally)
#   - Manual `claude-latest-install` command (writeShellApplication on PATH)
#
# Exit codes:
#   0 - Already installed (no-op) OR installer succeeded
#   non-zero - Installer failed (propagated from upstream)

set -euo pipefail

BIN="$HOME/.local/bin/claude"
STATE_DIR="$HOME/.local/share/claude"
TS() { date '+%Y-%m-%d %H:%M:%S'; }

# Fast path: already a symlink into the native install's versions directory.
if [ -L "$BIN" ]; then
  target="$(readlink "$BIN")"
  case "$target" in
    "$STATE_DIR"/versions/*)
      echo "$(TS) [INFO] claude-latest already installed at $BIN -> $target; skipping."
      exit 0
      ;;
  esac
fi

echo "$(TS) [INFO] Installing claude-latest via https://claude.ai/install.sh ..."
curl -fsSL https://claude.ai/install.sh | bash
echo "$(TS) [INFO] claude-latest install completed; $BIN -> $(readlink "$BIN" 2>/dev/null || echo '(not a symlink)')"
