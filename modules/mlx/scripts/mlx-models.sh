#!/usr/bin/env bash
# List all downloaded MLX models with memory fit status.
# Usage: mlx-models

hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"
port="${MLX_PORT:-11434}"
api="${MLX_API_URL:-http://127.0.0.1:$port/v1}"

total_bytes=$(sysctl -n hw.memsize)
total_gb=$(( total_bytes / 1073741824 ))
available_gb=$(( total_gb - 20 ))

# Get currently running model
running_model=$(curl -sf "$api/models" 2>/dev/null | jq -r '.data[0].id // ""' 2>/dev/null || echo "")

printf "%-55s %8s %8s %s\n" "MODEL" "SIZE" "EST.MEM" "STATUS"
printf "%-55s %8s %8s %s\n" "-----" "----" "-------" "------"

for model_dir in "$hf_home/hub"/models--*; do
  [ -d "$model_dir" ] || continue

  # Convert cache path back to model ID
  dir_name=$(basename "$model_dir")
  model_id="${dir_name#models--}"
  model_id="${model_id//--//}"

  # Size in GB
  read -r size_gb est_gb < <(
    du -sk "$model_dir" | awk '{
      gb = int($1 / 1048576 + 0.5)
      est = int(gb * 1.3 + 0.5)
      print gb, est
    }'
  )

  # Status
  if [ "$size_gb" -gt "$available_gb" ]; then
    status="NO-FIT"
  elif [ "$est_gb" -gt "$available_gb" ]; then
    status="TIGHT"
  else
    status="OK"
  fi

  # Running indicator
  marker="  "
  if [ "$model_id" = "$running_model" ]; then
    marker="* "
  fi

  printf "%s%-53s %5d GB %5d GB %s\n" "$marker" "$model_id" "$size_gb" "$est_gb" "$status"
done

echo ""
echo "System: ${total_gb} GB total, 20 GB reserved, ${available_gb} GB available for models"
echo "* = currently running"
