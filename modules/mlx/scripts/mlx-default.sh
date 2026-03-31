#!/usr/bin/env bash
# Safety net to restore the default LaunchAgent.
# Usage: mlx-default

label="dev.vllm-mlx.server"
domain="gui/$(id -u)"

# Acquire the same lock as mlx-switch to prevent racing with an in-progress switch
LOCK_FILE="${TMPDIR:-/tmp}/mlx-switch.lock"
/usr/bin/shlock -f "$LOCK_FILE" -p $$ || { echo "An mlx-switch is in progress. Wait for it to finish."; exit 1; }
trap 'rm -f "$LOCK_FILE"' EXIT

launchctl bootout "$domain/$label" 2>/dev/null || true
lsof -ti :"${MLX_PORT:?}" 2>/dev/null | xargs kill 2>/dev/null || true
sleep 1
launchctl bootstrap "$domain" "$HOME/Library/LaunchAgents/$label.plist" 2>/dev/null || true
echo "Default model restored."
