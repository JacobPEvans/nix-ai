#!/usr/bin/env zsh
# =============================================================================
# Auto-Claude: Autonomous AI Maintenance Daemon
# =============================================================================
# Runs Claude autonomously via launchd to perform maintenance tasks on git repos.
# Uses Python modules for complex logic (preflight checks, postrun processing).
#
# Usage: auto-claude.sh <target_dir> <max_budget_usd> [log_dir] [slack_channel]
#
# Environment:
# - FORCE_RUN=1 : Bypass pause/skip checks (used by auto-claude-ctl run)
# =============================================================================

set -euo pipefail

# --- ARGUMENT PARSING ---
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <target_dir> <max_budget_usd> [log_dir] [slack_channel]" >&2
  exit 1
fi

TARGET_DIR="$1"
MAX_BUDGET_USD="$2"
LOG_DIR="${3:-$HOME/.claude/logs}"
SLACK_CHANNEL="${4:-}"

# --- PATHS ---
SCRIPT_DIR="${HOME}/.claude/scripts"
NOTIFIER="${SCRIPT_DIR}/auto-claude-notify.py"
PROMPT_FILE="${SCRIPT_DIR}/orchestrator-prompt.txt"

# --- KEYCHAIN SECRETS ---
# Retrieve secrets from macOS automation keychain for headless operation
# This provides early fallback before Python preflight runs
AUTOMATION_KEYCHAIN="${HOME}/Library/Keychains/automation.keychain-db"
KEYCHAIN_ACCOUNT="ai-cli-coder"

# Function to get a secret from the automation keychain
get_keychain_secret() {
  local service_name="$1"
  if ! command -v security >/dev/null 2>&1; then
    echo "Warning: 'security' command not found. Cannot retrieve secrets from keychain." >&2
    return 1
  fi

  # Capture both stdout and stderr to detect actual errors
  local output exit_code
  output=$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$service_name" -w "$AUTOMATION_KEYCHAIN" 2>&1) || {
    exit_code=$?
    # Only log if it's a real error (not just "item not found" which is expected for optional secrets)
    if [[ $exit_code -ne 44 ]]; then  # 44 is "item not found" error code
      echo "Error: Failed to retrieve keychain secret for service '$service_name' (exit code: $exit_code)" >&2
    fi
    return $exit_code
  }
  echo "$output"
}

# Get BWS access token (required for Slack notifier to authenticate with Bitwarden)
if [[ -z "${BWS_ACCESS_TOKEN:-}" ]] && [[ -f "$AUTOMATION_KEYCHAIN" ]]; then
  _token=$(get_keychain_secret "bws-access-token") || true
  if [[ -n "$_token" ]]; then
    export BWS_ACCESS_TOKEN="$_token"
  fi
fi

# Get Slack channel from keychain if not provided as argument
# Channels are stored as SLACK_CHANNEL_ID_<REPO_NAME> (uppercase, dashes/dots to underscores)
if [[ -z "$SLACK_CHANNEL" ]] && [[ -f "$AUTOMATION_KEYCHAIN" ]]; then
  # Normalize repo name: basename, uppercase, replace dashes/dots with underscores
  REPO_BASENAME=$(basename "${TARGET_DIR%/}")
  REPO_KEY=${${(U)REPO_BASENAME}//[-.]/_}
  KEYCHAIN_SERVICE="SLACK_CHANNEL_ID_${REPO_KEY}"
  SLACK_CHANNEL=$(get_keychain_secret "$KEYCHAIN_SERVICE") || true
fi

# --- SSH AGENT SETUP FOR GIT OPERATIONS ---
# LaunchD agents don't inherit the user's SSH agent
# Start a new agent and add keys from macOS Keychain if available
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  eval "$(ssh-agent -s 2>/dev/null)" || true
  # Add keys from Keychain (requires AddKeysToAgent and UseKeychain in SSH config)
  ssh-add --apple-use-keychain 2>/dev/null || true
fi

# --- GIT SSH BATCH MODE ---
# If SSH agent has no identities, configure git to fail fast on SSH by forcing
# SSH BatchMode (this only affects git's SSH operations, not gh CLI auth).
# gh CLI authentication is handled separately via its config directory
# (controlled by GH_CONFIG_DIR in the Nix configuration).
if ! ssh-add -l >/dev/null 2>&1; then
  export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"
fi

# --- INPUT VALIDATION ---
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Directory $TARGET_DIR does not exist." >&2
  exit 1
fi

if ! [[ "$MAX_BUDGET_USD" =~ ^[0-9]+\.?[0-9]*$ ]] || ! awk -v val="$MAX_BUDGET_USD" 'BEGIN { exit !(val > 0) }'; then
  echo "Error: MAX_BUDGET_USD must be a positive number, got: $MAX_BUDGET_USD" >&2
  exit 1
fi

# --- LOGGING SETUP ---
if ! mkdir -p "$LOG_DIR"; then
  echo "Error: Cannot create log directory $LOG_DIR" >&2
  exit 1
fi

RUN_ID=$(date "+%Y%m%d_%H%M%S")
REPO_NAME=$(basename "${TARGET_DIR%/}")
LOG_FILE="$LOG_DIR/${REPO_NAME}_${RUN_ID}.jsonl"
SUMMARY_LOG="$LOG_DIR/summary.log"
FAILURES_LOG="$LOG_DIR/failures.log"

# --- ENVIRONMENT SETUP ---
# NOTE: We intentionally do NOT source .zshrc or .profile here.
# LaunchD agents should run in a controlled environment defined by the plist.
# The launchd plist sets PATH to include /etc/profiles/per-user/<user>/bin
# which provides home-manager packages (python3 with slack_sdk, etc.)
# Sourcing interactive shell configs would override PATH and cause issues.

# --- PYTHON PREFLIGHT CHECKS ---
FORCE_FLAG=""
[[ "${FORCE_RUN:-}" == "1" ]] && FORCE_FLAG="--force"

# Run all preflight checks via Python
PREFLIGHT_RESULT=$(python3 "${SCRIPT_DIR}/auto_claude_preflight.py" all "$TARGET_DIR" $FORCE_FLAG --json) || {
  PREFLIGHT_EXIT=$?
  if [[ $PREFLIGHT_EXIT -eq 2 ]]; then
    # Skip requested (paused or skip_count)
    SKIP_REASON=$(echo "$PREFLIGHT_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reason','unknown'))" 2>/dev/null || echo "unknown")
    echo "[$RUN_ID] SKIPPED: $SKIP_REASON" >> "$SUMMARY_LOG"

    # Send skip notification if Slack is available
    if [[ -n "$SLACK_CHANNEL" ]] && [[ -x "$NOTIFIER" ]]; then
      python3 "$NOTIFIER" run_skipped --repo "$REPO_NAME" --reason "$SKIP_REASON" --channel "$SLACK_CHANNEL" 2>/dev/null || true
    fi
    exit 0
  fi
  # Extract failure reason if available
  PREFLIGHT_REASON=$(echo "$PREFLIGHT_RESULT" | python3 -c "import sys, json; data=sys.stdin.read(); obj=json.loads(data) if data else {}; print(obj.get('reason') or obj.get('error') or obj.get('message') or '')" 2>/dev/null || echo "")
  if [[ -n "$PREFLIGHT_REASON" ]]; then
    echo "[$RUN_ID] ERROR: Preflight checks failed (exit=$PREFLIGHT_EXIT, reason=$PREFLIGHT_REASON)" >> "$FAILURES_LOG"
  else
    echo "[$RUN_ID] ERROR: Preflight checks failed (exit=$PREFLIGHT_EXIT)" >> "$FAILURES_LOG"
  fi
  exit 1
}

# Extract channel from preflight if not provided
if [[ -z "$SLACK_CHANNEL" ]]; then
  SLACK_CHANNEL=$(echo "$PREFLIGHT_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('channel',{}).get('channel',''))" 2>/dev/null || true)
fi

# Extract repo name from preflight (more accurate for worktrees)
DETECTED_REPO=$(echo "$PREFLIGHT_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('channel',{}).get('repo_name',''))" 2>/dev/null || true)
[[ -n "$DETECTED_REPO" ]] && REPO_NAME="$DETECTED_REPO"

# --- WORKTREE SETUP ---
# Determine repository structure and set up isolated worktree for this run
if [[ ! -e "$TARGET_DIR/.git" ]]; then
  echo "[$RUN_ID] ERROR: $TARGET_DIR is not a git repository" >> "$FAILURES_LOG"
  exit 1
fi

# Determine the bare repo location
pushd "$TARGET_DIR" >/dev/null || {
  echo "[$RUN_ID] ERROR: Cannot access $TARGET_DIR" >> "$FAILURES_LOG"
  exit 1
}
BARE_REPO=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
popd >/dev/null

if [[ -n "$BARE_REPO" ]] && [[ "$BARE_REPO" != ".git" ]]; then
  # This is a worktree - find the parent (bare repo)
  BARE_REPO=$(dirname "$BARE_REPO")
else
  # This is a regular repo - use its parent for worktree creation
  BARE_REPO=$(dirname "$TARGET_DIR")
fi

# Sync main worktree with origin
echo "[$RUN_ID] INFO: Syncing main worktree..." >> "$SUMMARY_LOG"
pushd "$TARGET_DIR" >/dev/null || {
  echo "[$RUN_ID] ERROR: Cannot cd to $TARGET_DIR" >> "$FAILURES_LOG"
  exit 1
}
# Determine default branch dynamically
DEFAULT_BRANCH=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[[ -z "$DEFAULT_BRANCH" ]] && DEFAULT_BRANCH="main"

git fetch origin 2>&1 | tee -a "$FAILURES_LOG" || {
  popd >/dev/null
  echo "[$RUN_ID] ERROR: git fetch failed" >> "$FAILURES_LOG"
  exit 1
}
git pull --ff-only origin "$DEFAULT_BRANCH" 2>&1 | tee -a "$FAILURES_LOG" || {
  popd >/dev/null
  echo "[$RUN_ID] ERROR: Fast-forward pull failed in main worktree" >> "$FAILURES_LOG"
  exit 1
}
popd >/dev/null

# Create worktree for this run
TIMESTAMP=$(date "+%Y-%m-%d-%H%M")
WORKTREE_NAME="auto-claude-${TIMESTAMP}"
WORKTREE_DIR="${BARE_REPO}/worktrees/${WORKTREE_NAME}"
BRANCH_NAME="${WORKTREE_NAME}"

# Ensure worktrees directory exists
mkdir -p "${BARE_REPO}/worktrees" || {
  echo "[$RUN_ID] ERROR: Cannot create worktrees directory" >> "$FAILURES_LOG"
  exit 1
}

# Create worktree branching from origin/main
echo "[$RUN_ID] INFO: Creating worktree at $WORKTREE_DIR" >> "$SUMMARY_LOG"
ORIGINAL_TARGET_DIR="$TARGET_DIR"
pushd "$ORIGINAL_TARGET_DIR" >/dev/null || {
  echo "[$RUN_ID] ERROR: Cannot cd to $ORIGINAL_TARGET_DIR" >> "$FAILURES_LOG"
  exit 1
}
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" origin/main 2>/dev/null || {
  popd >/dev/null
  echo "[$RUN_ID] ERROR: git worktree add failed" >> "$FAILURES_LOG"
  exit 1
}
popd >/dev/null

# Update TARGET_DIR to point to the new worktree
TARGET_DIR="$WORKTREE_DIR"

# --- PRE-FLIGHT DEPENDENCY CHECKS ---
cd "$TARGET_DIR" || {
  echo "[$RUN_ID] ERROR: Cannot cd to worktree $TARGET_DIR" >> "$FAILURES_LOG"
  # Clean up worktree on cd failure
  if [[ -n "$WORKTREE_DIR" ]]; then
    pushd "$ORIGINAL_TARGET_DIR" >/dev/null && git worktree remove "$WORKTREE_DIR" --force 2>/dev/null && popd >/dev/null || true
  fi
  exit 1
}

if ! command -v claude &>/dev/null; then
  echo "[$RUN_ID] ERROR: Claude CLI not found in PATH" >> "$FAILURES_LOG"
  exit 1
fi

if [[ ! -r "$PROMPT_FILE" ]]; then
  echo "[$RUN_ID] ERROR: Orchestrator prompt not found at $PROMPT_FILE" >> "$FAILURES_LOG"
  exit 1
fi

# --- SLACK SETUP ---
SLACK_ENABLED=false
if [[ -n "$SLACK_CHANNEL" ]] && [[ -x "$NOTIFIER" ]] && command -v python3 &>/dev/null; then
  SLACK_ENABLED=true
fi

# --- EMIT PREFLIGHT PASSED EVENT ---
python3 "${SCRIPT_DIR}/auto_claude_postrun.py" emit-event preflight_passed \
  --run-id "$RUN_ID" --repo "$REPO_NAME" \
  --extra "target_dir=$TARGET_DIR" "budget=$MAX_BUDGET_USD" || true

# --- SLACK: RUN STARTED ---
PARENT_TS=""
if [[ "$SLACK_ENABLED" == "true" ]]; then
  PARENT_TS=$(python3 "$NOTIFIER" run_started \
    --repo "$REPO_NAME" \
    --budget "$MAX_BUDGET_USD" \
    --run-id "$RUN_ID" \
    --channel "$SLACK_CHANNEL") || true
fi

# --- EXECUTION ---
echo "" >> "$SUMMARY_LOG"
echo "=== [$RUN_ID] Starting: $REPO_NAME ===" >> "$SUMMARY_LOG"
echo "    Target: $TARGET_DIR" >> "$SUMMARY_LOG"
echo "    Budget: \$${MAX_BUDGET_USD}" >> "$SUMMARY_LOG"
[[ -n "$PARENT_TS" ]] && echo "    Slack thread: $PARENT_TS" >> "$SUMMARY_LOG"

# Emit run_started event
python3 "${SCRIPT_DIR}/auto_claude_postrun.py" emit-event run_started \
  --run-id "$RUN_ID" --repo "$REPO_NAME" --budget "$MAX_BUDGET_USD" \
  --extra "slack_enabled=$SLACK_ENABLED" || true

START_TIME=$(date +%s)
ORCHESTRATOR_PROMPT=$(<"$PROMPT_FILE")

set +e
# Use gtimeout (macOS via coreutils) or timeout (Linux), fallback to no timeout
TIMEOUT_CMD=""
command -v gtimeout &>/dev/null && TIMEOUT_CMD="gtimeout 3600"
command -v timeout &>/dev/null && [[ -z "$TIMEOUT_CMD" ]] && TIMEOUT_CMD="timeout 3600"

# Determine model from environment variable (set by launchd via nix config)
# Defaults to haiku if not set, with explicit --model flag for defense-in-depth
CLAUDE_MODEL_TO_USE="${CLAUDE_MODEL:-haiku}"

$TIMEOUT_CMD claude -p "$ORCHESTRATOR_PROMPT" \
  --model "$CLAUDE_MODEL_TO_USE" \
  --output-format stream-json \
  --verbose \
  --max-budget-usd "$MAX_BUDGET_USD" \
  --no-session-persistence \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${pipestatus[1]}
set -e

# --- POST-RUN PROCESSING ---
END_TIME=$(date +%s)
DURATION_SEC=$((END_TIME - START_TIME))
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Check context usage via Python
python3 "${SCRIPT_DIR}/auto_claude_postrun.py" check-context "$LOG_FILE" \
  --run-id "$RUN_ID" --repo "$REPO_NAME" || true

# Emit run_completed event
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "=== [$TIMESTAMP] Completed: $REPO_NAME (exit 0) ===" >> "$SUMMARY_LOG"
  python3 "${SCRIPT_DIR}/auto_claude_postrun.py" emit-event run_completed \
    --run-id "$RUN_ID" --repo "$REPO_NAME" --exit-code 0 --duration "$DURATION_SEC" || true
else
  echo "=== [$TIMESTAMP] Failed: $REPO_NAME (exit $EXIT_CODE) ===" >> "$SUMMARY_LOG"
  echo "[$RUN_ID] $REPO_NAME: Exit code $EXIT_CODE" >> "$FAILURES_LOG"
  python3 "${SCRIPT_DIR}/auto_claude_postrun.py" emit-event run_completed \
    --run-id "$RUN_ID" --repo "$REPO_NAME" --exit-code "$EXIT_CODE" --duration "$DURATION_SEC" || true
fi

# --- SLACK: RUN COMPLETED ---
if [[ "$SLACK_ENABLED" == "true" ]] && [[ -n "$PARENT_TS" ]]; then
  python3 "$NOTIFIER" run_completed \
    --repo "$REPO_NAME" \
    --channel "$SLACK_CHANNEL" \
    --thread-ts "$PARENT_TS" \
    --budget "$MAX_BUDGET_USD" \
    --run-id "$RUN_ID" \
    --log-file "$LOG_FILE" || true
fi

# --- MONITORING: CHECK FOR ANOMALIES ---
MONITOR_SCRIPT="${SCRIPT_DIR}/auto-claude-monitor.py"
if [[ -x "$MONITOR_SCRIPT" ]] && [[ "${CLAUDE_MONITORING_ENABLED:-0}" == "1" ]] && [[ "$SLACK_ENABLED" == "true" ]]; then
  declare -a monitor_args=(--run-id "$RUN_ID" --repo "$REPO_NAME" --log-file "$LOG_FILE" --channel "$SLACK_CHANNEL")
  [[ -n "${CLAUDE_ALERT_CONTEXT_THRESHOLD:-}" ]] && monitor_args+=(--context-threshold "$CLAUDE_ALERT_CONTEXT_THRESHOLD")
  [[ -n "${CLAUDE_ALERT_BUDGET_THRESHOLD:-}" ]] && monitor_args+=(--budget-threshold "$CLAUDE_ALERT_BUDGET_THRESHOLD")
  [[ -n "${CLAUDE_ALERT_TOKENS_NO_OUTPUT:-}" ]] && monitor_args+=(--tokens-no-output "$CLAUDE_ALERT_TOKENS_NO_OUTPUT")
  [[ -n "${CLAUDE_ALERT_CONSECUTIVE_FAILURES:-}" ]] && monitor_args+=(--consecutive-failures "$CLAUDE_ALERT_CONSECUTIVE_FAILURES")
  python3 "$MONITOR_SCRIPT" "${monitor_args[@]}" >&2 || true
fi

# --- UPDATE CONTROL FILE (only on success) ---
if [[ $EXIT_CODE -eq 0 ]]; then
  python3 "${SCRIPT_DIR}/auto_claude_postrun.py" update-control "$REPO_NAME" || true
fi

# --- WORKTREE CLEANUP ---
if [[ -n "${WORKTREE_DIR:-}" ]] && [[ -d "$WORKTREE_DIR" ]]; then
  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "[$RUN_ID] INFO: Cleaning up worktree (success)" >> "$SUMMARY_LOG"

    # Remove worktree and branch - only proceed if we can cd to the correct directory
    if pushd "$ORIGINAL_TARGET_DIR" >/dev/null 2>&1; then
      git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || {
        echo "[$RUN_ID] WARNING: Failed to remove worktree $WORKTREE_DIR" >> "$SUMMARY_LOG"
      }
      git branch -D "$BRANCH_NAME" 2>/dev/null || {
        echo "[$RUN_ID] WARNING: Failed to delete branch $BRANCH_NAME" >> "$SUMMARY_LOG"
      }
      popd >/dev/null || true
    else
      echo "[$RUN_ID] WARNING: Cannot cd to $ORIGINAL_TARGET_DIR for cleanup, worktree preserved at $WORKTREE_DIR" >> "$SUMMARY_LOG"
    fi
  else
    echo "[$RUN_ID] INFO: Preserving worktree for inspection (failed run): $WORKTREE_DIR" >> "$SUMMARY_LOG"
    echo "    To clean up manually: cd \"$ORIGINAL_TARGET_DIR\" && git worktree remove \"$WORKTREE_DIR\" --force" >> "$SUMMARY_LOG"
  fi
fi

echo "" >> "$SUMMARY_LOG"
exit "$EXIT_CODE"
