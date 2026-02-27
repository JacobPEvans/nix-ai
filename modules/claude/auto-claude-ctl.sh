#!/usr/bin/env zsh

# =============================================================================
# auto-claude-ctl: Runtime Control for Auto-Claude Scheduler
# =============================================================================
# Provides runtime control over auto-claude scheduling without modifying Nix.
# Uses a control file that auto-claude.sh checks before each run.
#
# Usage: auto-claude-ctl <command> [args...]
#
# Commands:
#   run                   Actually run auto-claude immediately (bypasses scheduler)
#   pause <hours>         Pause all runs for specified hours
#   skip <count>          Skip the next N scheduled runs
#   resume                Clear pause/skip, resume normal schedule
#   status                Show current control state and schedule
#   schedule [h:m ...]    Show or set override schedule (e.g., "9:30 14:00 18:30")
#   clear-schedule        Clear override schedule, use Nix-defined times
#
# Control file: ~/.claude/auto-claude-control.json
# =============================================================================

set -euo pipefail

# Check for required dependencies
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install it to use this script." >&2
  exit 1
fi

CONTROL_FILE="${HOME}/.claude/auto-claude-control.json"
SCRIPT_DIR="${HOME}/.claude/scripts"
AUTO_CLAUDE_SCRIPT="${SCRIPT_DIR}/auto-claude.sh"

# Ensure control directory exists
mkdir -p "$(dirname "$CONTROL_FILE")"

# Initialize control file if missing
init_control_file() {
  if [[ ! -f "$CONTROL_FILE" ]]; then
    cat > "$CONTROL_FILE" << 'EOF'
{
  "pause_until": null,
  "skip_count": 0,
  "override_schedule": null,
  "last_run": null,
  "last_run_repo": null,
  "notes": "Control file for auto-claude scheduling. Edit with auto-claude-ctl."
}
EOF
  fi
}

# Read JSON field (requires jq)
read_field() {
  local field="$1"
  jq -r ".$field // empty" "$CONTROL_FILE" 2>/dev/null || echo ""
}

# Update JSON field
update_field() {
  local field="$1"
  local value="$2"
  local tmp
  tmp=$(mktemp) || { echo "Error: could not create temporary file for updating control file." >&2; return 1; }
  if [[ -z "$tmp" || ! -f "$tmp" ]]; then
    echo "Error: invalid temporary file path: '$tmp'" >&2
    return 1
  fi
  if jq ".$field = $value" "$CONTROL_FILE" > "$tmp"; then
    mv "$tmp" "$CONTROL_FILE"
  else
    echo "Error: failed to update control file with jq." >&2
    rm -f "$tmp"
    return 1
  fi
}

# Format timestamp for display
# Supports both macOS (BSD date) and Linux (GNU date)
format_time() {
  local ts="$1"
  if [[ -z "$ts" || "$ts" == "null" ]]; then
    echo "never"
  else
    # Convert ISO to readable format (cross-platform)
    if date --version >/dev/null 2>&1; then
      # GNU date (Linux)
      date -d "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts"
    else
      # BSD date (macOS)
      date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts"
    fi
  fi
}

# Convert ISO8601 timestamp to epoch seconds for reliable comparison
# Supports both macOS (BSD date) and Linux (GNU date)
iso_to_epoch() {
  local iso="$1"
  if date --version >/dev/null 2>&1; then
    # GNU date (Linux)
    date -d "$iso" "+%s" 2>/dev/null
  else
    # BSD date (macOS)
    date -j -f "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" "+%s" 2>/dev/null
  fi
}

# Command: run - actually run auto-claude now
# Usage: auto-claude-ctl run [repo-name]
# If repo-name is provided, runs that specific repo. Otherwise, lists available repos.
cmd_run() {
  init_control_file
  local target_repo="${1:-}"

  # Find configured repository paths from launchd plists
  local plist_dir="${HOME}/Library/LaunchAgents"
  local found_plists=()
  local found_names=()

  # Collect all auto-claude plists
  # Enable nullglob so glob expands to nothing if no matches (instead of literal pattern)
  setopt nullglob
  for plist in "$plist_dir"/com.claude.auto-claude-*.plist; do
    if [[ -f "$plist" ]]; then
      local name=$(basename "$plist" | sed 's/com.claude.auto-claude-//; s/.plist//')
      found_plists+=("$plist")
      found_names+=("$name")
    fi
  done

  if [[ ${#found_plists[@]} -eq 0 ]]; then
    echo "Error: No auto-claude configurations found in LaunchAgents" >&2
    echo "Looking for: $plist_dir/com.claude.auto-claude-*.plist" >&2
    exit 1
  fi

  # If no target specified and multiple repos exist, show list
  if [[ -z "$target_repo" && ${#found_plists[@]} -gt 1 ]]; then
    echo "Multiple repositories configured. Please specify which one to run:"
    echo ""
    for name in "${found_names[@]}"; do
      echo "  auto-claude-ctl run $name"
    done
    exit 0
  fi

  # Find the target plist
  local selected_plist=""
  if [[ -z "$target_repo" ]]; then
    # Only one repo, use it
    selected_plist="${found_plists[1]}"
  else
    # Find matching repo
    for i in {1..${#found_names[@]}}; do
      if [[ "${found_names[$i]}" == "$target_repo" ]]; then
        selected_plist="${found_plists[$i]}"
        break
      fi
    done
  fi

  if [[ -z "$selected_plist" ]]; then
    echo "Error: Repository '$target_repo' not found. Available repositories:" >&2
    for name in "${found_names[@]}"; do
      echo "  - $name" >&2
    done
    exit 1
  fi

  # Extract arguments from selected plist
  local repo_path=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:1" "$selected_plist" 2>/dev/null || true)
  local max_budget=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:2" "$selected_plist" 2>/dev/null || true)
  local log_dir=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:3" "$selected_plist" 2>/dev/null || true)
  local slack_channel=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:4" "$selected_plist" 2>/dev/null || true)

  if [[ -z "$repo_path" || -z "$max_budget" ]]; then
    echo "Error: Could not read configuration from $selected_plist" >&2
    exit 1
  fi

  echo "Running auto-claude immediately..."
  echo "  Repository: $repo_path"
  echo "  Budget: \$${max_budget}"
  echo ""

  # Run with FORCE_RUN=1 to bypass pause/skip checks
  FORCE_RUN=1 "$AUTO_CLAUDE_SCRIPT" "$repo_path" "$max_budget" "$log_dir" "$slack_channel"
}

# Command: pause - pause for N hours
cmd_pause() {
  local hours="${1:-}"
  if [[ -z "$hours" || ! "$hours" =~ ^[0-9]+$ ]]; then
    echo "Usage: auto-claude-ctl pause <hours>" >&2
    exit 1
  fi

  init_control_file

  # Date arithmetic with cross-platform support (BSD/macOS and GNU/Linux)
  local pause_until
  if date -v +1H "+%Y-%m-%dT%H:%M:%S" >/dev/null 2>&1; then
    # BSD/macOS date
    pause_until=$(date -v "+${hours}H" "+%Y-%m-%dT%H:%M:%S")
  else
    # GNU/Linux date
    pause_until=$(date -d "+${hours} hours" "+%Y-%m-%dT%H:%M:%S")
  fi

  update_field "pause_until" "\"$pause_until\""

  echo "Auto-claude paused until $(format_time "$pause_until")"
  echo "Run 'auto-claude-ctl resume' to resume earlier."
}

# Command: skip - skip next N runs
cmd_skip() {
  local count="${1:-}"
  if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
    echo "Usage: auto-claude-ctl skip <count>" >&2
    exit 1
  fi

  init_control_file
  update_field "skip_count" "$count"

  echo "Will skip the next $count scheduled run(s)."
  echo "Run 'auto-claude-ctl resume' to clear."
}

# Command: resume - clear pause/skip
cmd_resume() {
  init_control_file
  update_field "pause_until" "null"
  update_field "skip_count" "0"

  echo "Resumed normal scheduling. Pause and skip cleared."
}

# Command: status - show current state
cmd_status() {
  init_control_file

  echo "Auto-Claude Control Status"
  echo "=========================="
  echo ""

  local pause_until=$(read_field "pause_until")
  local skip_count=$(jq -r '.skip_count // 0' "$CONTROL_FILE" 2>/dev/null || echo 0)
  local override=$(jq -c '.override_schedule // empty' "$CONTROL_FILE" 2>/dev/null)
  local last_run=$(read_field "last_run")
  local last_repo=$(read_field "last_run_repo")

  # Check pause status
  if [[ -n "$pause_until" && "$pause_until" != "null" ]]; then
    local now=$(date "+%Y-%m-%dT%H:%M:%S")
    local now_epoch=$(iso_to_epoch "$now")
    local pause_until_epoch=$(iso_to_epoch "$pause_until")
    if [[ -z "$now_epoch" || -z "$pause_until_epoch" ]]; then
      echo "Warning: Could not parse pause_until or current time. Displaying raw values." >&2
      echo "Status: PAUSED until $(format_time "$pause_until") (parse error)"
    elif [[ "$now_epoch" -lt "$pause_until_epoch" ]]; then
      echo "Status: PAUSED until $(format_time "$pause_until")"
    else
      echo "Status: Active (pause expired)"
    fi
  elif [[ "$skip_count" -gt 0 ]]; then
    echo "Status: SKIPPING next $skip_count run(s)"
  else
    echo "Status: Active"
  fi

  echo ""
  echo "Skip count: ${skip_count:-0}"
  echo ""

  if [[ -n "$override" && "$override" != "null" ]]; then
    echo "Override schedule: $override"
  else
    echo "Schedule: Using Nix-defined times"
  fi

  echo ""
  echo "Last run: $(format_time "$last_run") (${last_repo:-unknown repo})"
  echo ""
  echo "Control file: $CONTROL_FILE"
}

# Command: schedule - show or set override schedule
cmd_schedule() {
  init_control_file

  if [[ $# -eq 0 ]]; then
    # Show current schedule
    local override=$(jq -c '.override_schedule // empty' "$CONTROL_FILE" 2>/dev/null)
    if [[ -n "$override" && "$override" != "null" ]]; then
      echo "Override schedule active:"
      echo "$override" | jq -r '.[] | "  \(.hour):\(if .minute < 10 then "0" else "" end)\(.minute)"'
    else
      echo "No override schedule. Using Nix-defined times."
      echo ""
      echo "To set override: auto-claude-ctl schedule 9:00 14:30 18:00"
    fi
  else
    # Parse and set schedule
    local schedule="["
    local first=true
    for time in "$@"; do
      if [[ ! "$time" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        echo "Error: Invalid time format '$time'. Use H:MM or HH:MM (e.g., 9:30 or 14:00)" >&2
        exit 1
      fi
      # Extract hour and minute using zsh's match array (populated by =~ operator)
      # Note: zsh arrays are 1-indexed, and match[1] is first capture group
      local hour="${match[1]}"
      local minute="${match[2]}"

      if [[ "$hour" -lt 0 || "$hour" -gt 23 ]]; then
        echo "Error: Hour must be 0-23, got $hour" >&2
        exit 1
      fi
      if [[ "$minute" -lt 0 || "$minute" -gt 59 ]]; then
        echo "Error: Minute must be 0-59, got $minute" >&2
        exit 1
      fi

      if [[ "$first" == "true" ]]; then
        first=false
      else
        schedule+=","
      fi
      schedule+="{\"hour\":$hour,\"minute\":$minute}"
    done
    schedule+="]"

    update_field "override_schedule" "$schedule"
    echo "Override schedule set:"
    echo "$schedule" | jq -r '.[] | "  \(.hour):\(if .minute < 10 then "0" else "" end)\(.minute)"'
    echo ""
    echo "Note: This overrides Nix-defined schedule until cleared."
    echo "Run 'auto-claude-ctl clear-schedule' to restore Nix schedule."
  fi
}

# Command: clear-schedule - clear override schedule
cmd_clear_schedule() {
  init_control_file
  update_field "override_schedule" "null"
  echo "Override schedule cleared. Using Nix-defined times."
}

# Main dispatch
case "${1:-}" in
  run)
    shift
    cmd_run "$@"
    ;;
  pause)
    shift
    cmd_pause "$@"
    ;;
  skip)
    shift
    cmd_skip "$@"
    ;;
  resume)
    cmd_resume
    ;;
  status)
    cmd_status
    ;;
  schedule)
    shift
    cmd_schedule "$@"
    ;;
  clear-schedule)
    cmd_clear_schedule
    ;;
  -h|--help|help|"")
    cat << 'EOF'
auto-claude-ctl: Runtime control for auto-claude scheduler

Usage: auto-claude-ctl <command> [args...]

Commands:
  run [repo-name]       Run auto-claude immediately (bypass scheduler)
  pause <hours>         Pause all runs for specified hours
  skip <count>          Skip the next N scheduled runs
  resume                Clear pause/skip, resume normal schedule
  status                Show current control state
  schedule [h:m ...]    Show or set override schedule times
  clear-schedule        Clear override, use Nix-defined times
  help                  Show this help

Examples:
  auto-claude-ctl pause 4          # Pause for 4 hours
  auto-claude-ctl skip 2           # Skip next 2 runs
  auto-claude-ctl schedule 9:00 14:30 18:00  # Run at these times
  auto-claude-ctl run              # Run right now

Control file: ~/.claude/auto-claude-control.json
EOF
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Run 'auto-claude-ctl help' for usage." >&2
    exit 1
    ;;
esac
