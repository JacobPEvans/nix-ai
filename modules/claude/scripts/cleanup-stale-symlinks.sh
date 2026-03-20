#!/usr/bin/env bash
# Remove stale nix-store symlinks (target is in /nix/store AND no longer exists).
# Usage (sourced): . this-script path1 path2 ...
# Requires: DRY_RUN_CMD from activation scope.

# Requires: log_info, log_warn from cleanup-common.sh (sourced by caller)

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
