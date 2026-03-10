# ClaudeCodeStatusLine Implementation (daniel3303)
#
# 2-LINE STATUSLINE STANDARD:
# All statusline implementations should output exactly 2 lines:
#   Line 1 (context): what am I working on — model, location, token state
#   Line 2 (limits):  what are my constraints — rate limits, effort, extras
#
# This is a 2-line variant of https://github.com/daniel3303/ClaudeCodeStatusLine
# Original focuses on rate limits and token usage with color thresholds.
#
# Features:
#   - 5-hour and 7-day rate limit tracking
#   - Effort level (low/med/high reasoning) indicator
#   - Color-coded warnings: green <50% → yellow → orange → red ≥90%
#   - 60-second caching of API responses at /tmp/claude/statusline-usage-cache.json
#   - Runtime dependencies: jq, bc, curl, git (wired through Nix)
#
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claudeStatuslineDaniel3303;

  # 2-line statusline script (daniel3303 variant)
  statuslineScript = pkgs.writeShellScript "claude-statusline-daniel3303" ''
    #!/usr/bin/env bash
    set -e

    # ANSI color codes for threshold warnings
    COLOR_GREEN='\033[32m'
    COLOR_YELLOW='\033[33m'
    COLOR_ORANGE='\033[38;5;214m'
    COLOR_RED='\033[31m'
    COLOR_RESET='\033[0m'
    DIM='\033[2m'

    # Parse CLAUDE_STATUS_LINE_DATA from Claude Code environment
    # Format: model|effort|tokens|...
    parse_statusline_data() {
      local data="$CLAUDE_STATUS_LINE_DATA"
      [[ "$data" =~ ([^|]+)\|([^|]+)\|([^|]+) ]] && {
        MODEL="''${BASH_REMATCH[1]}"
        EFFORT="''${BASH_REMATCH[2]}"
        TOKENS="''${BASH_REMATCH[3]}"
      }
      # Defaults if not set
      MODEL="''${MODEL:-claude-sonnet}"
      EFFORT="''${EFFORT:-—}"
      TOKENS="''${TOKENS:-—}"
    }

    # Get git info: current branch and uncommitted changes
    get_git_info() {
      local branch unstaged staged
      if branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
        # Count unstaged+staged changes
        local changes=$(git diff --stat 2>/dev/null | tail -1 | awk '{print $NF}' || echo "")
        [[ -n "$changes" ]] && branch="''${branch}+''${changes}" || branch="''${branch}"
      else
        branch="—"
      fi
      echo "$branch"
    }

    # Get current working directory (relative to home if possible)
    get_working_dir() {
      local cwd="''${PWD#$HOME/}"
      [[ "$cwd" == "$PWD" ]] && cwd="$PWD"
      echo "$cwd"
    }

    # Fetch Claude API rate limit usage (with 60s cache)
    get_rate_limit_data() {
      local cache_dir="/tmp/claude"
      local cache_file="$cache_dir/statusline-usage-cache.json"
      local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f%m "$cache_file" 2>/dev/null || echo 0)))

      # Use cache if valid (< 60 seconds old)
      if [[ -f "$cache_file" && $cache_age -lt 60 ]]; then
        cat "$cache_file"
        return 0
      fi

      # Fetch fresh data (requires ANTHROPIC_API_KEY)
      if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo '{"limit_5h": "—", "limit_7d": "—", "reset_5h": "—", "reset_7d": "—"}'
        return 0
      fi

      mkdir -p "$cache_dir"
      local response
      response=$(curl -s -H "api-key: $ANTHROPIC_API_KEY" \
        "https://api.anthropic.com/v1/usage" 2>/dev/null || echo '{}')

      # Parse response and cache it
      echo "$response" > "$cache_file" 2>/dev/null || true
      echo "$response"
    }

    # Format rate limit with color based on usage percentage
    format_limit() {
      local current=$1
      local limit=$2
      local label=$3
      local reset=$4

      # Calculate percentage (0-100)
      local percent=$([[ "$current" -gt 0 && "$limit" -gt 0 ]] && echo "scale=0; (100 * $current) / $limit" | ${pkgs.bc}/bin/bc || echo 0)

      # Select color based on threshold
      local color="$COLOR_GREEN"
      [[ $percent -ge 50 ]] && color="$COLOR_YELLOW"
      [[ $percent -ge 75 ]] && color="$COLOR_ORANGE"
      [[ $percent -ge 90 ]] && color="$COLOR_RED"

      # Format: label percent% (reset_time)
      printf "%b%s %d%%''${COLOR_RESET}" "$color" "$label" "$percent"
    }

    # --- Main Script ---

    # Parse Claude Code environment
    parse_statusline_data

    # Get git context
    cwd=$(get_working_dir)
    branch=$(get_git_info)

    # Get rate limit data (cached)
    rate_data=$(get_rate_limit_data)

    # Extract rate limit values (graceful defaults if parsing fails)
    limit_5h=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.limit_5h // "—"' 2>/dev/null || echo "—")
    used_5h=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.used_5h // 0' 2>/dev/null || echo 0)
    reset_5h=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.reset_5h // "—"' 2>/dev/null || echo "—")

    limit_7d=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.limit_7d // "—"' 2>/dev/null || echo "—")
    used_7d=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.used_7d // 0' 2>/dev/null || echo 0)
    reset_7d=$(echo "$rate_data" | ${pkgs.jq}/bin/jq -r '.reset_7d // "—"' 2>/dev/null || echo "—")

    # --- OUTPUT ---
    # Line 1: Context (what am I working on)
    printf "%s ''${DIM}|''${COLOR_RESET} %s@%s ''${DIM}|''${COLOR_RESET} %s tokens\n" \
      "$MODEL" "$cwd" "$branch" "$TOKENS"

    # Line 2: Limits (what are my constraints)
    printf "%s ''${DIM}|''${COLOR_RESET} " "$EFFORT"
    format_limit "$used_5h" "$limit_5h" "5h" "$reset_5h"
    printf " ''${DIM}|''${COLOR_RESET} "
    format_limit "$used_7d" "$limit_7d" "7d" "$reset_7d"
    printf "\n"
  '';

in
{
  config = lib.mkIf cfg.enable {
    programs.claude.statusLine = {
      enable = true;
      script = ''
        #!/usr/bin/env bash
        # ClaudeCodeStatusLine (daniel3303) - 2-line format
        exec ${statuslineScript} "$@"
      '';
    };
  };
}
