#!/usr/bin/env bash
# Safe wrapper for raw MLX benchmark — runs preflight before loading model.
# This is the most dangerous benchmark tool: it bypasses all vllm-mlx memory
# controls (no memory-aware cache, no LRU eviction).
# Usage: mlx-bench-raw [mlx_lm.benchmark args...]

model=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--model" ]; then model="$arg"; fi
  prev="$arg"
done

if [ -n "$model" ]; then
  mlx-preflight "$model" || exit 1
fi

# Hard cap: raw MLX has NO memory controls — ulimit is our only safety net
ulimit -v $((110 * 1024 * 1024)) 2>/dev/null || true

exec uvx --from mlx-lm mlx_lm.benchmark "$@"
