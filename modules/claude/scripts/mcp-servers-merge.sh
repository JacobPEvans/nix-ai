#!/usr/bin/env bash
# Merge mcpServers into ~/.claude.json (user-scoped global config).
# Sourced from settings.nix activation with MCP_SERVERS_JSON set in environment.
# Nix is the sole manager of the mcpServers key — any entries added via
# `claude mcp add --scope user` will be overwritten on next darwin-rebuild switch.
# Requires: MCP_SERVERS_JSON, DRY_RUN_CMD (from activation scope), jq on PATH.

CLAUDE_JSON="$HOME/.claude.json"

if [ -f "$CLAUDE_JSON" ]; then
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if jq --argjson v "$MCP_SERVERS_JSON" '.mcpServers = $v' \
    "$CLAUDE_JSON" > "$TMP"; then
    $DRY_RUN_CMD mv "$TMP" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: Failed to update \"$CLAUDE_JSON\"; existing file may contain invalid JSON. Fix or remove it to apply mcpServers settings." >&2
    rm -f "$TMP"
  fi
else
  $DRY_RUN_CMD printf '{"mcpServers": %s}\n' "$MCP_SERVERS_JSON" > "$CLAUDE_JSON"
fi

$DRY_RUN_CMD chmod 600 "$CLAUDE_JSON"
