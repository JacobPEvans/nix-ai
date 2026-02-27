#!/usr/bin/env bash
# Remove directory symlinks pointing to /nix/store (conflicts with per-file symlinks).
# Usage (sourced): . this-script dir1 dir2 ...
# Requires: DRY_RUN_CMD from activation scope.

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }

for dir in "$@"; do
  if [ -L "$dir" ]; then
    TARGET=$(readlink "$dir")
    if [[ "$TARGET" == /nix/store/* ]]; then
      if $DRY_RUN_CMD rm "$dir"; then
        log_info "Removed conflicting directory symlink: $dir"
        log_info "  (was: $TARGET)"
      else
        log_warn "Failed to remove directory symlink: $dir"
      fi
    fi
  fi
done
