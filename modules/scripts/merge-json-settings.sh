#!/usr/bin/env bash
# Deep-merge Nix-generated JSON settings with existing runtime state.
# Generic script used by multiple tools (Gemini, Claude, etc.).
#
# Canonical source: nix-home/modules/home-manager/scripts/merge-json-settings.sh
# Keep in sync when modifying. Full dedup planned when nix-home becomes a flake input.
#
# Preserves runtime-only keys while updating Nix-managed settings.
# Merge strategy: existing runtime file as base, Nix config overlaid on top.
# Nix-managed keys always win, but runtime-only keys are preserved.
#
# Arguments:
#   $1 - Path to Nix-generated settings JSON (in /nix/store)
#   $2 - Path to target settings file
#
# jq must be on PATH (callers ensure this via PATH export or writeShellApplication).

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: merge-json-settings <nix-settings-path> <target-path>" >&2
  exit 1
fi

NIX_SETTINGS="$1"
TARGET="$2"

TARGET_NAME=$(basename "$TARGET")
TARGET_DIR=$(dirname "$TARGET")
mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET" ]] && [[ ! -L "$TARGET" ]]; then
  # File exists and is a real file (not symlink) - merge
  # Strip Nix-authoritative sections from existing config before merge.
  # This prevents stale entries (e.g. removed MCP servers) from persisting.
  # del(.mcpServers) is a no-op on files without that key (safe for Claude settings.json).
  STRIPPED=$(jq 'del(.mcpServers)' "$TARGET" 2>/dev/null) || STRIPPED=$(cat "$TARGET")
  # jq -s '.[0] * .[1]' merges deeply: [0]=existing runtime (stripped), [1]=Nix config
  # Nix config wins on conflicts, runtime-only keys are preserved
  MERGED=$(printf '%s\n%s\n' "$STRIPPED" "$(cat "$NIX_SETTINGS")" | jq -s '.[0] * .[1]') || {
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
