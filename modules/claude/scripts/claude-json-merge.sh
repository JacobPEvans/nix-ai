#!/usr/bin/env bash
# Deep-merge a Nix-generated JSON overlay into ~/.claude.json.
# Sourced from settings.nix activation with OVERLAY_FILE set.
# Requires: OVERLAY_FILE, DRY_RUN_CMD (from activation scope), jq on PATH.
#
# Merge strategy:
# - Top-level keys from overlay replace existing values (mcpServers, remoteControlAtStartup)
# - .projects entries are deep-merged: overlay values merge INTO existing project entries
#   (preserving runtime-managed keys like allowedTools, mcpServers per-project, etc.)

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if jq -s '
    .[0] as $existing | .[1] as $overlay |
    ($overlay | del(.projects)) as $topLevel |
    ($overlay.projects // {}) as $newProjects |
    $existing * $topLevel |
    .projects = (
      ($existing.projects // {}) as $ep |
      reduce ($newProjects | keys[]) as $k ($ep;
        .[$k] = ((.[$k] // {}) * $newProjects[$k])
      )
    )
  ' "$CLAUDE_JSON" "$OVERLAY_FILE" > "$TMP"; then
    $DRY_RUN_CMD mv "$TMP" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: Failed to update \"$CLAUDE_JSON\"; existing file may contain invalid JSON. Fix or remove it to apply settings." >&2
    rm -f "$TMP"
  fi
else
  $DRY_RUN_CMD cp "$OVERLAY_FILE" "$CLAUDE_JSON"
fi

$DRY_RUN_CMD chmod 600 "$CLAUDE_JSON"
