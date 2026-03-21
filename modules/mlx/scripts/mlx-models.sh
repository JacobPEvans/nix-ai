#!/usr/bin/env bash
# List all downloaded MLX models with memory fit status.
# Usage: mlx-models

hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"
port="${MLX_PORT:-11434}"
api="${MLX_API_URL:-http://127.0.0.1:$port/v1}"
safety_gb="${MLX_SAFETY_OVERHEAD:-20}"

total_bytes=$(sysctl -n hw.memsize)
total_gb=$(( total_bytes / 1073741824 ))
available_gb=$(( total_gb - safety_gb ))

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

  # Size in GB (single awk call for precision; cache du results by mtime)
  cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/mlx-model-sizes"
  dir_mtime=$(stat -f "%m" "$model_dir")
  cached=$(grep "^${dir_name} ${dir_mtime} " "$cache_file" 2>/dev/null)
  if [ -n "$cached" ]; then
    read -r _ _ size_gb est_gb <<< "$cached"
  else
    read -r size_gb est_gb < <(
      du -sk "$model_dir" | awk '{
        gb = int($1 / 1048576 + 0.5)
        est = int(gb * 1.3 + 0.5)
        print gb, est
      }'
    )
    mkdir -p "$(dirname "$cache_file")"
    # Remove stale entry for this model, add fresh one
    grep -v "^${dir_name} " "$cache_file" 2>/dev/null > "${cache_file}.tmp" || true
    printf "%s %s %s %s\n" "$dir_name" "$dir_mtime" "$size_gb" "$est_gb" >> "${cache_file}.tmp"
    mv "${cache_file}.tmp" "$cache_file"
  fi

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
echo "System: ${total_gb} GB total, ${safety_gb} GB reserved, ${available_gb} GB available for models"
echo "* = currently running"
