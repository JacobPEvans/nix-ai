#!/usr/bin/env bash
# Show MLX inference server state.
# Usage: mlx-status

port="${MLX_PORT:?}"
api="${MLX_API_URL:?}"

if pid=$(lsof -ti :"$port" 2>/dev/null | head -1); then
  model=$(curl -sf "$api/models" | jq -r '.data[0].id // "unknown"' 2>/dev/null || echo "unknown")
  mem_mb=$(/usr/bin/footprint -p "$pid" 2>/dev/null \
    | awk '/Footprint:/ { for(i=1;i<=NF;i++) if($i=="Footprint:") {
        val=$(i+1); unit=$(i+2)
        if(unit~/GB/) printf "%.0f\n", val*1024
        else if(unit~/MB/) print val
        else if(unit~/KB/) printf "%.0f\n", val/1024
        exit }}')
  if [ -z "$mem_mb" ] || [ "$mem_mb" = "0" ]; then
    mem_kb=$(ps -o rss= -p "$pid" 2>/dev/null)
    mem_mb=$(( ${mem_kb:-0} / 1024 ))
  fi
  printf "running  pid=%s  model=%s  mem=%.1fGB  uptime=%s\n" \
    "$pid" "$model" "$(echo "scale=1; $mem_mb/1024" | bc)" "$(ps -o etime= -p "$pid")"
else
  echo "stopped"
fi
