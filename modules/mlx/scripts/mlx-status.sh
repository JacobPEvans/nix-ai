#!/usr/bin/env bash
# Show MLX inference server state.
# Usage: mlx-status

port="${MLX_PORT:?}"
api="${MLX_API_URL:?}"

if pid=$(lsof -ti :"$port" 2>/dev/null | head -1); then
  model=$(curl -sf "$api/models" | jq -r '.data[0].id // "unknown"' 2>/dev/null || echo "unknown")
  mem=$(ps -o rss= -p "$pid" 2>/dev/null || echo 0)
  printf "running  pid=%s  model=%s  mem=%.1fGB  uptime=%s\n" \
    "$pid" "$model" "$(echo "scale=1; $mem/1048576" | bc)" "$(ps -o etime= -p "$pid")"
else
  echo "stopped"
fi
