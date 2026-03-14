#!/usr/bin/env bash
# Show MLX inference server state.
# Usage: mlx-status

port="${MLX_PORT:?MLX_PORT not set}"
api="${MLX_API_URL:?MLX_API_URL not set}"
label="dev.vllm-mlx.server"

echo "=== MLX Server ==="
if pid=$(lsof -ti :"$port" 2>/dev/null | head -1); then
  echo "Status:  running (PID $pid)"
  echo "Uptime:  $(ps -o etime= -p "$pid" 2>/dev/null || echo unknown)"
  mem=$(ps -o rss= -p "$pid" 2>/dev/null || echo 0)
  echo "Memory:  $(echo "scale=1; $mem / 1048576" | bc 2>/dev/null || echo '?')GB"
  model=$(curl -sf "$api/models" 2>/dev/null | jq -r '.data[0].id // "unknown"' 2>/dev/null || echo "(no response)")
  echo "Model:   $model"
  echo "API:     $api"
else
  echo "Status:  stopped"
fi

launchctl list "$label" >/dev/null 2>&1 \
  && echo "Agent:   loaded" \
  || echo "Agent:   not loaded"
