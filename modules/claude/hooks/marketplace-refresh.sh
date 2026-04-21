#!/usr/bin/env bash
# Claude Code Hook: Refresh marketplace indexes after Nix rebuilds
#
# Reads the .nix-refresh-needed marker written by verify-cache-integrity.sh
# when Nix marketplace store paths change (i.e., after darwin-rebuild switch
# updates flake inputs). Refreshes each changed marketplace's index so that
# claude plugin list shows current versions from the updated Nix store content.
#
# Hook Type: sessionStart
# Triggers: At the start of every new Claude Code session
#
# Safety: Only runs when the marker file exists (a rebuild changed marketplace
# store paths). Does not delete cache directories. Does not invoke claude from
# home.activation. Best-effort: failures are logged but do not block session start.

set -euo pipefail

MARKER="${HOME}/.claude/plugins/cache/.nix-refresh-needed"

# Nothing to do — no rebuild changed marketplace paths since last refresh
[[ -f "$MARKER" ]] || exit 0

log_info() { echo "[marketplace-refresh] $1" >&2; }

# Read marketplaces from marker and refresh each one.
# Use while-read to stay compatible with macOS system bash (3.2).
failed_list=""
while IFS='=' read -r key value; do
  [[ "$key" == "marketplace" ]] || continue
  mp="$value"
  log_info "Refreshing marketplace index: $mp"
  if timeout 15 claude plugin marketplace update "$mp" >/dev/null 2>&1; then
    log_info "Refreshed: $mp"
  else
    log_info "Failed to refresh: $mp (will retry next session)"
    failed_list="${failed_list}${mp}:"
  fi
done < "$MARKER"

if [[ -z "$failed_list" ]]; then
  rm -f "$MARKER"
  log_info "All marketplace indexes refreshed"
else
  # Rewrite marker with only failed entries so the next session retries them
  tmp="$(mktemp "${MARKER}.XXXXXX")"
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  IFS=':' read -r -a failed_arr <<< "$failed_list"
  for mp in "${failed_arr[@]}"; do
    [[ -n "$mp" ]] && echo "marketplace=$mp" >> "$tmp"
  done
  mv "$tmp" "$MARKER"
  log_info "Partial refresh — ${#failed_arr[@]} marketplace(s) queued for next session"
fi

exit 0
