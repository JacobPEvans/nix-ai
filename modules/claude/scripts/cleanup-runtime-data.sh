#!/usr/bin/env bash
# Runtime Data Cleanup for ~/.claude
#
# Prunes stale session artifacts that accumulate over time.
# Runs on every home-manager switch via orphan-cleanup.nix Phase 4.
#
# Usage: cleanup-runtime-data.sh <home_dir> <retention_days> <max_backups>
#
# Safety: reads active session PIDs from ~/.claude/sessions/*.json before
# touching anything. Files/dirs matching an active session UUID are skipped.
# Projects dirs modified within the last hour are also skipped.

set -euo pipefail

# shellcheck source=cleanup-common.sh
. "$(dirname "$0")/cleanup-common.sh"

HOME_DIR="${1:?HOME_DIR required}"
RETENTION_DAYS="${2:-30}"
MAX_BACKUPS="${3:-5}"

CLAUDE_DIR="${HOME_DIR}/.claude"

# ────────────────────────────────────────────────
# Active session detection
# ────────────────────────────────────────────────

ACTIVE_UUIDS=()

if compgen -G "${CLAUDE_DIR}/sessions/*.json" >/dev/null 2>&1; then
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] && ACTIVE_UUIDS+=("$uuid")
  done < <(
    jq -r '.sessionId // .session_id // empty' "${CLAUDE_DIR}"/sessions/*.json 2>/dev/null | sort -u
  )
fi

log_info "Active sessions: ${#ACTIVE_UUIDS[@]}"

is_active_session() {
  local target="$1"
  for uuid in "${ACTIVE_UUIDS[@]}"; do
    [[ "$target" == *"$uuid"* ]] && return 0
  done
  return 1
}

# ────────────────────────────────────────────────
# Helper: delete items older than RETENTION_DAYS
# ────────────────────────────────────────────────

# Deletes files/dirs inside $dir older than RETENTION_DAYS, skipping active sessions.
prune_dir_by_age() {
  local dir="$1"
  local label="$2"
  [[ -d "$dir" ]] || return 0

  local count=0
  while IFS= read -r -d $'\0' item; do
    is_active_session "$item" && continue
    rm -rf "$item"
    count=$((count + 1))
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)

  [[ $count -gt 0 ]] && log_info "Pruned $count stale $label entries"
}

# ────────────────────────────────────────────────
# 1. Telemetry — always delete (failed events never retry)
# ────────────────────────────────────────────────

if [[ -d "${CLAUDE_DIR}/telemetry" ]]; then
  count=$(find "${CLAUDE_DIR}/telemetry" -name "1p_failed_events*" 2>/dev/null | wc -l | tr -d ' ')
  if [[ $count -gt 0 ]]; then
    find "${CLAUDE_DIR}/telemetry" -name "1p_failed_events*" -delete 2>/dev/null || true
    log_info "Removed $count failed telemetry events"
  fi
fi

# ────────────────────────────────────────────────
# 2. security_warnings_state_*.json — stale per-session files in ~/.claude root
# ────────────────────────────────────────────────

stale_warnings=0
while IFS= read -r -d $'\0' f; do
  is_active_session "$f" && continue
  rm -f "$f"
  stale_warnings=$((stale_warnings + 1))
done < <(find "${CLAUDE_DIR}" -maxdepth 1 -name "security_warnings_state_*.json" -print0 2>/dev/null)
[[ $stale_warnings -gt 0 ]] && log_info "Removed $stale_warnings stale security_warnings_state files"

# ────────────────────────────────────────────────
# 3. settings.local.json — delete if fully covered by settings.json wildcards
# ────────────────────────────────────────────────

LOCAL_JSON="${CLAUDE_DIR}/settings.local.json"
MAIN_JSON="${CLAUDE_DIR}/settings.json"

if [[ -f "$LOCAL_JSON" ]] && [[ -f "$MAIN_JSON" ]]; then
  all_redundant=true
  while IFS= read -r perm; do
    [[ -z "$perm" ]] && continue
    # Check if any entry in settings.json.permissions.allow covers this permission
    covered=$(jq -r --arg p "$perm" '
      .permissions.allow // [] |
      map(. as $pat |
        $p | test("^" + ($pat | gsub("\\*"; ".*")) + "$")
      ) | any
    ' "$MAIN_JSON" 2>/dev/null)
    if [[ "$covered" != "true" ]]; then
      all_redundant=false
      break
    fi
  done < <(jq -r '.permissions.allow // [] | .[]' "$LOCAL_JSON" 2>/dev/null)

  if $all_redundant; then
    rm -f "$LOCAL_JSON"
    log_info "Removed redundant settings.local.json (all permissions covered by settings.json)"
  fi
fi

# ────────────────────────────────────────────────
# 4. Known cruft files — always delete
# ────────────────────────────────────────────────

for cruft in \
  "${CLAUDE_DIR}/settings.json.backup-manual" \
  "${CLAUDE_DIR}/auto-claude-control.json"
do
  if [[ -f "$cruft" ]]; then
    rm -f "$cruft"
    log_info "Removed cruft: $(basename "$cruft")"
  fi
done

# ────────────────────────────────────────────────
# 5. Broken symlinks in ~/.claude root
# ────────────────────────────────────────────────

broken=0
while IFS= read -r -d $'\0' link; do
  rm -f "$link"
  broken=$((broken + 1))
done < <(find "${CLAUDE_DIR}" -maxdepth 2 -xtype l -print0 2>/dev/null)
[[ $broken -gt 0 ]] && log_info "Removed $broken broken symlinks"

# ────────────────────────────────────────────────
# 6. Known empty directories
# ────────────────────────────────────────────────

for empty_dir in \
  "${CLAUDE_DIR}/.claude" \
  "${CLAUDE_DIR}/downloads" \
  "${CLAUDE_DIR}/statusline" \
  "${CLAUDE_DIR}/debug" \
  "${CLAUDE_DIR}/powerline/locks"
do
  if [[ -d "$empty_dir" ]] && [[ -z "$(ls -A "$empty_dir" 2>/dev/null)" ]]; then
    rmdir "$empty_dir"
    log_info "Removed empty directory: ${empty_dir#"$HOME_DIR/"}"
  fi
done

# ────────────────────────────────────────────────
# 7. projects/ — delete session dirs inactive longer than RETENTION_DAYS
#    Extra guard: skip dirs modified within the last hour
# ────────────────────────────────────────────────

projects_dir="${CLAUDE_DIR}/projects"
if [[ -d "$projects_dir" ]]; then
  pruned_projects=0
  while IFS= read -r -d $'\0' proj; do
    is_active_session "$proj" && continue
    # Skip if modified within the last hour (race condition guard)
    if find "$proj" -mindepth 0 -maxdepth 0 -mmin -60 2>/dev/null | grep -q .; then
      continue
    fi
    rm -rf "$proj"
    pruned_projects=$((pruned_projects + 1))
  done < <(find "$projects_dir" -mindepth 1 -maxdepth 1 -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
  [[ $pruned_projects -gt 0 ]] && log_info "Pruned $pruned_projects stale project session dirs"
fi

# ────────────────────────────────────────────────
# 8–13. Session-keyed runtime data dirs
# ────────────────────────────────────────────────

prune_dir_by_age "${CLAUDE_DIR}/todos"          "todo"
prune_dir_by_age "${CLAUDE_DIR}/file-history"   "file-history"
prune_dir_by_age "${CLAUDE_DIR}/shell-snapshots" "shell-snapshot"
prune_dir_by_age "${CLAUDE_DIR}/session-env"    "session-env"
prune_dir_by_age "${CLAUDE_DIR}/paste-cache"    "paste-cache"
prune_dir_by_age "${CLAUDE_DIR}/plans"          "plan"
prune_dir_by_age "${CLAUDE_DIR}/tasks"          "task"

# ────────────────────────────────────────────────
# 14. backups — keep only the newest MAX_BACKUPS
# ────────────────────────────────────────────────

backups_dir="${CLAUDE_DIR}/backups"
if [[ -d "$backups_dir" ]]; then
  mapfile -d $'\0' backup_files < <(
    find "$backups_dir" -maxdepth 1 -name ".claude.json.backup.*" -print0 2>/dev/null |
    sort -z
  )
  excess=$(( ${#backup_files[@]} - MAX_BACKUPS ))
  if [[ $excess -gt 0 ]]; then
    for (( i=0; i<excess; i++ )); do
      rm -f "${backup_files[$i]}"
    done
    log_info "Removed $excess old backups (kept $MAX_BACKUPS)"
  fi
fi

# ────────────────────────────────────────────────
# 15. statsig/ — feature flag caches, 7-day retention
# ────────────────────────────────────────────────

if [[ -d "${CLAUDE_DIR}/statsig" ]]; then
  statsig_pruned=0
  while IFS= read -r -d $'\0' f; do
    rm -f "$f"
    statsig_pruned=$((statsig_pruned + 1))
  done < <(find "${CLAUDE_DIR}/statsig" -maxdepth 1 -mtime +7 -print0 2>/dev/null)
  [[ $statsig_pruned -gt 0 ]] && log_info "Pruned $statsig_pruned stale statsig cache files"
fi

# ────────────────────────────────────────────────
# 16. logs/ — delete log files older than RETENTION_DAYS
# ────────────────────────────────────────────────

if [[ -d "${CLAUDE_DIR}/logs" ]]; then
  logs_pruned=0
  while IFS= read -r -d $'\0' f; do
    rm -f "$f"
    logs_pruned=$((logs_pruned + 1))
  done < <(find "${CLAUDE_DIR}/logs" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS" -print0 2>/dev/null)
  [[ $logs_pruned -gt 0 ]] && log_info "Pruned $logs_pruned old log files"
fi

log_info "Runtime data cleanup complete (retention: ${RETENTION_DAYS}d, max backups: ${MAX_BACKUPS})"
