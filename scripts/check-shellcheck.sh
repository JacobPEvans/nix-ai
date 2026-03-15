#!/usr/bin/env bash
# Lint shell scripts with shellcheck.
# Excludes .git directories, result symlinks, and zsh scripts.
# --severity=warning: Only fail on warning/error level (not info style suggestions)
# SC1091: Exclude "not following" errors for external sources (can't resolve in Nix sandbox)
# Called from lib/checks.nix with shellcheck on PATH.
set -euo pipefail

find . -name "*.sh" -not -path "./.git/*" -not -path "./result/*" -print0 | \
xargs -0 bash -c '
  for script in "$@"; do
    # Skip zsh scripts (shellcheck does not support them)
    if head -1 "$script" | grep -q "zsh"; then
      echo "Skipping zsh script: $script"
    else
      echo "Checking $script..."
      shellcheck --severity=warning --exclude=SC1091 "$script"
    fi
  done
' bash
