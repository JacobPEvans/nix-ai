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

# Collect failed marketplaces in a temp file to avoid shell string splitting issues.
# Use while-read to stay compatible with macOS system bash (3.2).
failures_tmp="$(mktemp "${MARKER}.failures.XXXXXX")"
trap 'rm -f "$failures_tmp"' EXIT

failed_count=0
while IFS='=' read -r key value; do
  [[ "$key" == "marketplace" ]] || continue
  mp="$value"
  log_info "Refreshing marketplace index: $mp"
  # No timeout — claude plugin marketplace update has its own network timeout.
  # macOS does not ship the GNU coreutils timeout command.
  if claude plugin marketplace update "$mp" >/dev/null 2>&1; then
    log_info "Refreshed: $mp"
  else
    log_info "Failed to refresh: $mp (will retry next session)"
    echo "marketplace=$mp" >> "$failures_tmp"
    failed_count=$((failed_count + 1))
  fi
done < "$MARKER"

if [[ "$failed_count" -eq 0 ]]; then
  rm -f "$MARKER"
  log_info "All marketplace indexes refreshed"
else
  # Rewrite marker with only failed entries so the next session retries them
  tmp="$(mktemp "${MARKER}.XXXXXX")"
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  cat "$failures_tmp" >> "$tmp"
  mv "$tmp" "$MARKER"
  log_info "Partial refresh — ${failed_count} marketplace(s) queued for next session"
fi

exit 0
