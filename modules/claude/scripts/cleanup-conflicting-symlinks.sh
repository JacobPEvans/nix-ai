#!/usr/bin/env bash
# Remove entries that conflict with home-manager's link generation.
# Handles both directory symlinks (normal case) and real directories
# (one-time migration from recursive=true to directory symlinks).
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
  elif [ -d "$dir" ]; then
    # Real directory left over from old recursive=true setup.
    # Only remove if under the marketplaces path — component dirs (commands, agents,
    # skills) may contain user-created content and must never be rm -rf'd.
    case "$dir" in
      */.claude/plugins/marketplaces/*)
        if $DRY_RUN_CMD rm -rf "$dir"; then
          log_info "Removed real directory (migration to directory symlink): $dir"
        else
          log_warn "Failed to remove real directory: $dir"
        fi
        ;;
      *)
        log_warn "Skipping rm -rf for non-marketplace directory: $dir"
        ;;
    esac
  fi
done
