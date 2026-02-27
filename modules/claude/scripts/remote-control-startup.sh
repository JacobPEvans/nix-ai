#!/usr/bin/env bash
# Merge remoteControlAtStartup into ~/.claude.json.
# Sourced from settings.nix activation with RC_VALUE set in environment.
# Requires: RC_VALUE, DRY_RUN_CMD (from activation scope), jq on PATH.

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if jq --argjson v "$RC_VALUE" '.remoteControlAtStartup = $v' \
    "$CLAUDE_JSON" > "$TMP"; then
    $DRY_RUN_CMD mv "$TMP" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: Failed to update \"$CLAUDE_JSON\"; existing file may contain invalid JSON. Fix or remove it to apply remoteControlAtStartup setting." >&2
    rm -f "$TMP"
  fi
else
  $DRY_RUN_CMD printf '{"remoteControlAtStartup": %s}\n' "$RC_VALUE" > "$CLAUDE_JSON"
fi

$DRY_RUN_CMD chmod 600 "$CLAUDE_JSON"
