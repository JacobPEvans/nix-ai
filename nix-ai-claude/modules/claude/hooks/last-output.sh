#!/usr/bin/env bash
# Claude Code Hook: Capture Last Output
#
# Captures Claude's last response output to a file for statusline/terminal display.
# This enables quick reference to the most recent Claude action without scrolling.
#
# Hook Type: postToolUse
# Triggers: After any tool execution
#
# Environment Variables:
#   TOOL_NAME: Name of the tool that was invoked
#   TOOL_OUTPUT: Output from the tool execution
#   CLAUDE_SESSION_ID: Current session ID (if available)
#   CLAUDE_SESSION_DIR: Session directory path (if available)

set -euo pipefail

# Output file for last result (used by statusline or other display tools)
OUTPUT_FILE="${HOME}/.cache/claude-last-output.txt"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

# Ensure cache directory exists
mkdir -p "$OUTPUT_DIR"

# Extract a compact summary of the tool output
# For different tool types, we want different information:
case "${TOOL_NAME:-}" in
  "Bash")
    # For bash commands, show the command and exit code
    COMMAND=$(echo "${TOOL_INPUT:-}" | jq -r '.command // "unknown"' 2>/dev/null || echo "unknown")
    EXIT_CODE=$(echo "${TOOL_OUTPUT:-}" | jq -r '.exit_code // .exitCode // "?"' 2>/dev/null || echo "?")
    SUMMARY="bash: ${COMMAND:0:50} (exit: ${EXIT_CODE})"
    ;;

  "Read")
    # For file reads, show the file path
    FILE_PATH=$(echo "${TOOL_INPUT:-}" | jq -r '.file_path // .filePath // "unknown"' 2>/dev/null || echo "unknown")
    SUMMARY="read: $(basename "${FILE_PATH}")"
    ;;

  "Write"|"Edit")
    # For file writes/edits, show the file path
    FILE_PATH=$(echo "${TOOL_INPUT:-}" | jq -r '.file_path // .filePath // "unknown"' 2>/dev/null || echo "unknown")
    SUMMARY="$(echo "${TOOL_NAME}" | tr '[:upper:]' '[:lower:]'): $(basename "${FILE_PATH}")"
    ;;

  "Grep"|"Glob")
    # For searches, show the pattern
    PATTERN=$(echo "${TOOL_INPUT:-}" | jq -r '.pattern // "unknown"' 2>/dev/null || echo "unknown")
    SUMMARY="$(echo "${TOOL_NAME}" | tr '[:upper:]' '[:lower:]'): ${PATTERN:0:50}"
    ;;

  *)
    # For other tools, just show the tool name
    SUMMARY="${TOOL_NAME:-unknown}"
    ;;
esac

# Add timestamp
TIMESTAMP=$(date '+%H:%M:%S')
OUTPUT="${TIMESTAMP} ${SUMMARY}"

# Write to file (truncate to keep it compact)
echo "$OUTPUT" > "$OUTPUT_FILE"

# Optional: Also update a persistent log (append-only)
LOG_FILE="${HOME}/.cache/claude-output.log"
echo "$OUTPUT" >> "$LOG_FILE"

# Keep log file size under control (last 100 lines)
if [[ -f "$LOG_FILE" ]]; then
  TMP_LOG=$(mktemp)
  tail -n 100 "$LOG_FILE" > "$TMP_LOG" && mv "$TMP_LOG" "$LOG_FILE"
fi

exit 0
