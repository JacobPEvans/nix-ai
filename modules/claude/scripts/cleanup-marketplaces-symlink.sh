#!/usr/bin/env bash
# Remove stale Nix-managed symlink for known_marketplaces.json.
# Sourced from registry.nix activation with MARKETPLACES set in environment.

if [ -L "$MARKETPLACES" ]; then
  if $DRY_RUN_CMD rm "$MARKETPLACES"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Removed Nix-managed symlink for known_marketplaces.json (now Claude-managed)"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to remove Nix symlink at $MARKETPLACES (non-critical)" >&2
  fi
fi
