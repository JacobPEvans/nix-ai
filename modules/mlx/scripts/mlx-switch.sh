#!/usr/bin/env bash
# Foreground model switcher — auto-restores default on exit.
# Usage: mlx-switch mlx-community/Qwen3-235B-A22B-4bit

model="${1:?Usage: mlx-switch <model>}"
label="dev.vllm-mlx.server"
domain="gui/$(id -u)"
plist="$HOME/Library/LaunchAgents/$label.plist"

# Serialize model switches — only one at a time for optimal I/O scheduling.
LOCK_FILE="${TMPDIR:-/tmp}/mlx-switch.lock"
/usr/bin/shlock -f "$LOCK_FILE" -p $$ || { echo "Another mlx-switch is in progress. Aborting."; exit 1; }

trap 'lsof -ti :"$MLX_PORT" 2>/dev/null | xargs kill 2>/dev/null; sleep 1; launchctl bootstrap "$domain" "$plist" 2>/dev/null; rm -f "$LOCK_FILE"; echo "Default restored."' EXIT

mlx-preflight "$model" || exit 1

launchctl bootout "$domain/$label" 2>/dev/null || true
while lsof -ti :"${MLX_PORT:?}" >/dev/null 2>&1; do sleep 1; done

echo "Starting $model. Ctrl-C to restore default."
HF_HOME="${MLX_HF_HOME:-/Volumes/HuggingFace}" vllm-mlx serve "$model" \
  --port "$MLX_PORT" --host "${MLX_HOST:-127.0.0.1}"
