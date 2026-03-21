#!/usr/bin/env bash
# Safe wrapper for vllm-mlx throughput benchmark — runs preflight before loading model.
# Usage: mlx-bench-safe [vllm-mlx-bench args...]

# Extract --model argument (handles both --model value and --model=value)
model=""
prev=""
for arg in "$@"; do
  if [[ "$arg" == --model=* ]]; then
    model="${arg#*=}"
  elif [ "$prev" = "--model" ]; then
    model="$arg"
  fi
  prev="$arg"
done

if [ -n "$model" ]; then
  mlx-preflight "$model" || exit 1
fi

# Cap virtual memory at 110 GB (in KB) to prevent unbounded growth
ulimit -v $((110 * 1024 * 1024)) 2>/dev/null || true

exec vllm-mlx-bench "$@"
