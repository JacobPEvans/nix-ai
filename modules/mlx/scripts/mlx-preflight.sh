#!/usr/bin/env bash
# Pre-flight memory check — refuses to load models that would cause OOM.
# Usage: mlx-preflight <model-hf-id>
# Exit 0 = safe to load, Exit 1 = would OOM.
#
# Added after 2026-03-21 OOM incident where 3 python3.13 processes consumed
# 171.9 GB against 128 GB physical RAM.

model="${1:?Usage: mlx-preflight <model-hf-id>}"
hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"
safety_gb="${MLX_SAFETY_OVERHEAD:-20}"

# Resolve HuggingFace model ID to local cache path
# e.g., mlx-community/Qwen3-235B-A22B-4bit → models--mlx-community--Qwen3-235B-A22B-4bit
cache_name="models--${model//\/--}"
model_path="$hf_home/hub/$cache_name"

if [ ! -d "$model_path" ]; then
  echo "ERROR: Model not found at $model_path" >&2
  echo "Has it been downloaded? Check: ls $hf_home/hub/" >&2
  exit 1
fi

# Model disk size and estimated memory in GB (single awk call for precision)
read -r model_gb estimated_gb < <(
  du -sk "$model_path" | awk '{
    gb = int($1 / 1048576 + 0.5)
    est = int(gb * 1.3 + 0.5)
    print gb, est
  }'
)

# Total system RAM
total_bytes=$(sysctl -n hw.memsize)
total_gb=$(( total_bytes / 1073741824 ))

# Available = total - safety overhead
available_gb=$(( total_gb - safety_gb ))

if [ "$model_gb" -gt "$available_gb" ]; then
  echo "BLOCKED: Model too large for available memory" >&2
  echo "  Model size:     ${model_gb} GB (on disk)" >&2
  echo "  Est. memory:    ${estimated_gb} GB (model + KV cache)" >&2
  echo "  System RAM:     ${total_gb} GB" >&2
  echo "  Safety reserve: ${safety_gb} GB" >&2
  echo "  Available:      ${available_gb} GB" >&2
  echo "  Deficit:        $(( model_gb - available_gb )) GB over limit" >&2
  exit 1
fi

if [ "$estimated_gb" -gt "$available_gb" ]; then
  echo "WARNING: Model fits but KV cache may cause pressure" >&2
  echo "  Model size:     ${model_gb} GB" >&2
  echo "  Est. memory:    ${estimated_gb} GB (model + KV cache)" >&2
  echo "  Available:      ${available_gb} GB" >&2
  echo "  Headroom:       $(( available_gb - estimated_gb )) GB (tight)" >&2
  # Warning only — still allow loading
fi

echo "OK: ${model_gb} GB model fits in ${available_gb} GB available (${total_gb} GB total - ${safety_gb} GB reserved)"
exit 0
