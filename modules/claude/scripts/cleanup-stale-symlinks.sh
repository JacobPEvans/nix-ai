#!/usr/bin/env bash
# Remove stale nix-store symlinks (target is in /nix/store AND no longer exists).
# Usage (sourced): . this-script path1 path2 ...
# Requires: DRY_RUN_CMD from activation scope.

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }

for path in "$@"; do
  if [ -L "$path" ]; then
    TARGET=$(readlink "$path")
    if [[ "$TARGET" == /nix/store/* ]] && [ ! -e "$TARGET" ]; then
      if $DRY_RUN_CMD rm "$path"; then
        log_info "Removed stale symlink: $path"
      else
        log_warn "Failed to remove stale symlink: $path"
      fi
    fi
  fi
done
