#!/usr/bin/env bash
# Safe wrapper for vllm-mlx engine benchmark — runs preflight before loading model.
# Usage: mlx-bench-engine-safe [vllm-mlx bench args...]

model=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--model" ]; then model="$arg"; fi
  prev="$arg"
done

if [ -n "$model" ]; then
  mlx-preflight "$model" || exit 1
fi

ulimit -v $((110 * 1024 * 1024)) 2>/dev/null || true

exec vllm-mlx bench "$@"
