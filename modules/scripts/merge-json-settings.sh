#!/usr/bin/env bash
# Deep-merge Nix-generated JSON settings with existing runtime state.
# Generic script used by multiple tools (Gemini, VS Code, etc.).
#
# Preserves runtime-only keys while updating Nix-managed settings.
# Merge strategy: existing runtime file as base, Nix config overlaid on top.
# Nix-managed keys always win, but runtime-only keys are preserved.
#
# Arguments:
#   $1 - Path to Nix-generated settings JSON (in /nix/store)
#   $2 - Path to target settings file
#   $3 - Path to jq binary

set -euo pipefail

NIX_SETTINGS="${1:?Usage: merge-json-settings.sh <nix-settings-path> <target-path> <jq-path>}"
TARGET="${2:?Usage: merge-json-settings.sh <nix-settings-path> <target-path> <jq-path>}"
JQ="${3:?Usage: merge-json-settings.sh <nix-settings-path> <target-path> <jq-path>}"

TARGET_NAME=$(basename "$TARGET")
TARGET_DIR=$(dirname "$TARGET")
mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET" ]] && [[ ! -L "$TARGET" ]]; then
  # File exists and is a real file (not symlink) - merge
  # jq -s '.[0] * .[1]' merges deeply: [0]=existing runtime, [1]=Nix config
  # Nix config wins on conflicts, runtime-only keys are preserved
  MERGED=$("$JQ" -s '.[0] * .[1]' "$TARGET" "$NIX_SETTINGS" 2>/dev/null) || {
    # If merge fails (e.g., invalid JSON in target), just use Nix settings
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to merge existing ${TARGET_NAME}, using Nix config" >&2
    cp "$NIX_SETTINGS" "$TARGET"
    chmod 600 "$TARGET"
    exit 0
  }
  printf '%s\n' "$MERGED" > "${TARGET}.tmp"
  mv "${TARGET}.tmp" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Merged ${TARGET_NAME} (preserved runtime state)"
elif [[ -L "$TARGET" ]]; then
  # It's a symlink (old Nix-managed) - remove and create real file
  rm "$TARGET"
  cp "$NIX_SETTINGS" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Replaced Nix symlink with writable ${TARGET_NAME}"
else
  # No existing file - just copy
  cp "$NIX_SETTINGS" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Created initial ${TARGET_NAME}"
fi
