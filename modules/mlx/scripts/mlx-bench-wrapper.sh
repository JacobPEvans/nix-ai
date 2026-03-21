#!/usr/bin/env bash
# Shared OOM-safe wrapper for MLX benchmark tools.
# Runs mlx-preflight before loading a model, caps virtual memory at 110 GB.
# Usage: mlx-bench-wrapper <command> [args...]
#   command: the benchmark executable or command to run after safety checks

cmd="${1:?Usage: mlx-bench-wrapper <command> [args...]}"
shift

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

exec $cmd "$@"
