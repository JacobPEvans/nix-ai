#!/usr/bin/env bash
# Verify Claude Code plugin cache integrity after Nix rebuilds
# Removes stale cache entries when marketplace store paths change
#
# When Nix updates marketplace symlinks to new /nix/store paths,
# Claude Code's cached plugin data becomes stale and must be purged.
# See: https://github.com/anthropics/claude-code/issues/17361

set -euo pipefail

# Centralized logging function (stderr for diagnostics)
log_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2
}

HOME_DIR="${1:?Usage: verify-cache-integrity.sh <home-dir>}"
MARKETPLACES_DIR="$HOME_DIR/.claude/plugins/marketplaces"
CACHE_DIR="$HOME_DIR/.claude/plugins/cache"
HASH_FILE="$CACHE_DIR/.nix-store-hashes"

# Only run if both dirs exist
[[ -d "$MARKETPLACES_DIR" ]] || exit 0
[[ -d "$CACHE_DIR" ]] || exit 0

# Load existing hashes
declare -A old_hashes
if [[ -f "$HASH_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -n "$key" ]] && old_hashes["$key"]="$value"
  done < "$HASH_FILE"
fi

# Build new hashes, purge stale caches
# Marketplaces are real directories containing per-file symlinks to /nix/store/
# (after transition from whole-directory symlinks via recursive=true in plugins.nix)
declare -A new_hashes
# Use find with process substitution to avoid a for loop, per repo guidelines
while IFS= read -r -d '' entry; do
  name=$(basename "$entry")

  # Find the first Nix store symlink inside this marketplace directory
  target=""
  while IFS= read -r -d '' link; do
    t=$(readlink "$link")
    if [[ "$t" == /nix/store/* ]]; then
      target="$t"
      break
    fi
  done < <(find "$entry" -maxdepth 3 -type l -print0 2>/dev/null)
  [[ -n "$target" ]] || continue

  # Hash the store path string (not file contents - that's what matters for staleness)
  hash=$(printf '%s' "$target" | shasum -a 256 | cut -d' ' -f1)
  new_hashes["$name"]="$hash"

  if [[ "${old_hashes[$name]:-}" != "$hash" ]]; then
    if [[ -d "$CACHE_DIR/$name" ]]; then
      rm -rf "$CACHE_DIR/$name"
      log_info "Purged stale cache: $name"
      log_info "  Store path changed to: $target"
    fi
  fi
done < <(find "$MARKETPLACES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# Write updated hashes atomically to avoid leaving a partially written file
mkdir -p "$CACHE_DIR"
tmp_hash_file="$(mktemp "${HASH_FILE}.XXXXXX")"
for name in "${!new_hashes[@]}"; do
  echo "${name}=${new_hashes[$name]}" >> "$tmp_hash_file"
done
mv "$tmp_hash_file" "$HASH_FILE"
