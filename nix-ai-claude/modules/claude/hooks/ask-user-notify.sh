#!/usr/bin/env bash
# Claude Code Hook: Notify on AskUserQuestion
#
# Sends Slack notification when Claude Code needs user input.
# This enables mobile/async workflows where users may not be watching the terminal.
#
# Hook Type: preToolUse
# Triggers: When Claude calls AskUserQuestion tool
#
# Environment Variables:
#   TOOL_NAME: Name of the tool being invoked
#   TOOL_INPUT: JSON input to the tool
#   CLAUDE_SESSION_ID: Current session ID (if available)
#   CLAUDE_SESSION_DIR: Session directory path (if available)

set -euo pipefail

# Only trigger for AskUserQuestion
if [[ "${TOOL_NAME:-}" != "AskUserQuestion" ]]; then
  exit 0
fi

# Extract question from tool input
# Try multiple JSON paths since the structure varies:
# - .question (single question)
# - .questions[0].question (multiple questions)
# - .prompt (alternative field name)
QUESTION=$(echo "${TOOL_INPUT:-{}}" | jq -r '.question // .questions[0].question // .prompt // "User input needed"' 2>/dev/null || echo "User input needed")

# Get current working directory and repo name
REPO_NAME=$(basename "$(pwd)")
SESSION_INFO="${REPO_NAME}"

# Add session context if available
if [[ -n "${CLAUDE_SESSION_DIR:-}" ]]; then
  SESSION_BRANCH=$(git -C "$(pwd)" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  SESSION_INFO="${REPO_NAME} @ ${SESSION_BRANCH}"
fi

# Get Slack channel from environment or keychain
SLACK_CHANNEL="${SLACK_CHANNEL:-}"
if [[ -z "$SLACK_CHANNEL" ]]; then
  # Try to get from keychain (format: SLACK_CHANNEL_<REPO>)
  KEYCHAIN_KEY="SLACK_CHANNEL_$(echo "$REPO_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
  SLACK_CHANNEL=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_KEY" -w 2>/dev/null || echo "")
fi

# If still no channel, use default or skip notification
if [[ -z "$SLACK_CHANNEL" ]]; then
  # Silent exit - don't break Claude Code if notifications aren't configured
  exit 0
fi

# Call auto-claude-notify.py with user_input_needed event
# Script is deployed by home-manager to ~/.claude/scripts/
NOTIFY_SCRIPT="${HOME}/.claude/scripts/auto-claude-notify.py"
if [[ -x "$NOTIFY_SCRIPT" ]]; then
  if ! "$NOTIFY_SCRIPT" user_input_needed \
    --session "$SESSION_INFO" \
    --question "$QUESTION" \
    --channel "$SLACK_CHANNEL" >&2; then
    echo "Warning: Notification script failed to send message." >&2
  fi
fi

exit 0
