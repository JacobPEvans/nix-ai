#!/usr/bin/env bash
# Remove broken symlinks (target does not exist) inside component directories.
# Usage (sourced): . this-script type1 dir1 type2 dir2 ...
# Requires: DRY_RUN_CMD from activation scope.

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }

while [ $# -ge 2 ]; do
  type_name="$1"
  dir="$2"
  shift 2
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type l -print0 | while IFS= read -d $'\0' -r link; do
      if [ ! -e "$link" ]; then
        if $DRY_RUN_CMD rm "$link"; then
          log_info "Removed orphan ${type_name}: $(basename "$link")"
        else
          log_warn "Failed to remove orphan ${type_name}: $(basename "$link")"
        fi
      fi
    done
  fi
done
