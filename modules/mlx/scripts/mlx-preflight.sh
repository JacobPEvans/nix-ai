#!/usr/bin/env bash
# Pre-flight memory check — refuses to load models that would cause OOM.
# Usage: mlx-preflight <model-hf-id>
# Exit 0 = safe to load, Exit 1 = would OOM.

model="${1:?Usage: mlx-preflight <model-hf-id>}"
hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"

# Resolve HuggingFace model ID to local cache path
cache_name="models--${model//\/--}"
model_path="$hf_home/hub/$cache_name"

if [ ! -d "$model_path" ]; then
  echo "ERROR: Model not found at $model_path" >&2
  echo "Has it been downloaded? Check: ls $hf_home/hub/" >&2
  exit 1
fi

# Model disk size and estimated runtime memory (1.3x for KV cache overhead)
read -r model_gb estimated_gb < <(
  du -sk "$model_path" | awk '{
    gb = int($1 / 1048576 + 0.5)
    est = int(gb * 1.3 + 0.5)
    print gb, est
  }'
)

# Available = total RAM - 20GB reserved for OS + apps
total_bytes=$(sysctl -n hw.memsize)
total_gb=$(( total_bytes / 1073741824 ))
available_gb=$(( total_gb - 20 ))

if [ "$estimated_gb" -gt "$available_gb" ]; then
  echo "BLOCKED: Model too large for available memory" >&2
  echo "  Model size:  ${model_gb} GB (on disk)" >&2
  echo "  Est. memory: ${estimated_gb} GB (model + KV cache)" >&2
  echo "  Available:   ${available_gb} GB (${total_gb} GB - 20 GB reserved)" >&2
  exit 1
fi

echo "OK: ${model_gb} GB model fits in ${available_gb} GB available"
