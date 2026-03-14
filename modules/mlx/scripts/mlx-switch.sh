#!/usr/bin/env bash
# Foreground model switcher — auto-restores default on exit.
# Usage: mlx-switch mlx-community/Qwen3-235B-A22B-4bit

model="${1:?Usage: mlx-switch <model>}"
label="dev.vllm-mlx.server"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

restore() {
  echo ""
  echo "Restoring default model..."
  lsof -ti :"${MLX_PORT:?}" 2>/dev/null | xargs kill 2>/dev/null || true
  sleep 1
  launchctl bootstrap "$domain" "$plist" 2>/dev/null || true
  echo "Default model restored."
}
trap restore EXIT

launchctl bootout "$domain/$label" 2>/dev/null || true

# Wait for port to free
for _ in $(seq 1 30); do
  lsof -ti :"$MLX_PORT" >/dev/null 2>&1 || break
  sleep 1
done

echo "Starting $model on port $MLX_PORT (foreground). Ctrl-C to restore default."
HF_HOME="${MLX_HF_HOME:-/Volumes/HuggingFace}" vllm-mlx serve "$model" \
  --port "$MLX_PORT" --host "${MLX_HOST:-127.0.0.1}"
