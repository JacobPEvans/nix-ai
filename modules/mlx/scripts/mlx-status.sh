#!/usr/bin/env bash
# Show MLX inference server state.
# Usage: mlx-status

port="${MLX_PORT:?}"
api="${MLX_API_URL:?}"

# The process on $port is now the llama-swap proxy, not vllm-mlx.
# Find the actual vllm-mlx backend for memory reporting.
if lsof -ti :"$port" 2>/dev/null | head -1 > /dev/null; then
  model=$(curl -sf "$api/models" | jq -r '.data[0].id // "unknown"' 2>/dev/null || echo "unknown")

  # Get memory from the vllm-mlx child process (the real memory consumer).
  vllm_pid=$(pgrep -f "vllm-mlx serve" 2>/dev/null | head -1)
  proxy_pid=$(lsof -ti :"$port" 2>/dev/null | head -1)

  if [ -n "$vllm_pid" ]; then
    mem_mb=$(/usr/bin/footprint -p "$vllm_pid" 2>/dev/null \
      | awk '/Footprint:/ { for(i=1;i<=NF;i++) if($i=="Footprint:") {
          val=$(i+1); unit=$(i+2)
          if(unit~/GB/) printf "%.0f\n", val*1024
          else if(unit~/MB/) print val
          else if(unit~/KB/) printf "%.0f\n", val/1024
          exit }}')
    if [ -z "$mem_mb" ] || [ "$mem_mb" = "0" ]; then
      mem_kb=$(ps -o rss= -p "$vllm_pid" 2>/dev/null)
      mem_mb=$(( ${mem_kb:-0} / 1024 ))
    fi
    uptime=$(ps -o etime= -p "$vllm_pid")
  else
    mem_mb=0
    uptime="n/a"
    vllm_pid="none"
  fi

  printf "running  proxy_pid=%s  vllm_pid=%s  model=%s  mem=%.1fGB  uptime=%s\n" \
    "$proxy_pid" "$vllm_pid" "$model" "$(echo "scale=1; $mem_mb/1024" | bc)" "$uptime"
else
  echo "stopped"
fi
