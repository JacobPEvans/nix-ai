#!/usr/bin/env bash
# Safety net to restore the default LaunchAgent.
# Usage: mlx-default

label="dev.vllm-mlx.server"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

launchctl bootout "$domain/$label" 2>/dev/null || true
lsof -ti :"${MLX_PORT:?}" 2>/dev/null | xargs kill 2>/dev/null || true
sleep 1
lsof -ti :"$MLX_PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true

launchctl bootstrap "$domain" "$plist" 2>/dev/null || true
echo "Default model restored."
