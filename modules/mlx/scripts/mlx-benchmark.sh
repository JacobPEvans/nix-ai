#!/usr/bin/env bash
# Orchestrate benchmark runs across models and suites.
#
# Usage:
#   mlx-benchmark                                        # All suites, current model
#   mlx-benchmark --model mlx-community/gemma-4-31b-it-4bit  # All suites, specific model
#   mlx-benchmark --suite throughput,ttft                # Specific suites only
#   mlx-benchmark --all-models                           # All suites, every fitting model
#   mlx-benchmark --all-models --suite throughput        # One suite across all models
#   mlx-benchmark --warmup 5                             # Custom warmup count
#   mlx-benchmark --dry-run                              # Validate without running inference

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────────────────────────────
all_suites="throughput,ttft,tool-calling,code-accuracy,coding,reasoning,knowledge,framework-eval,capability-comparison"
suites="$all_suites"
model="${MLX_DEFAULT_MODEL:-}"
all_models=false
warmup=3
dry_run=false
output_dir=""
repo_root=""

# ──────────────────────────────────────────────────────────────────────
# Parse arguments
# ──────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      model="${2:?--model requires a value}"
      shift 2
      ;;
    --suite)
      suites="${2:?--suite requires a value}"
      shift 2
      ;;
    --all-models)
      all_models=true
      shift
      ;;
    --warmup)
      warmup="${2:?--warmup requires a value}"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --output-dir)
      output_dir="${2:?--output-dir requires a value}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: mlx-benchmark [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --model MODEL       Model ID to benchmark (default: \$MLX_DEFAULT_MODEL)"
      echo "  --suite SUITES      Comma-separated suite list (default: all)"
      echo "  --all-models        Benchmark every downloaded model that fits in memory"
      echo "  --warmup N          Warmup requests before benchmarking (default: 3)"
      echo "  --dry-run           Validate without running inference"
      echo "  --output-dir DIR    Override result output directory"
      echo "  -h, --help          Show this help"
      echo ""
      echo "Suites: $all_suites"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────
# Locate repo root (for collect-results.py and generate-summary.py)
# ──────────────────────────────────────────────────────────────────────
find_repo_root() {
  local dir
  dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/flake.nix" ] && [ -d "$dir/scripts/benchmarks" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Fallback: check common locations
  for candidate in "$HOME/git/nix-ai/main" "$HOME/git/nix-ai/feat/"*; do
    if [ -d "$candidate/scripts/benchmarks" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

repo_root="$(find_repo_root)" || {
  echo "ERROR: Cannot find nix-ai repo root (need scripts/benchmarks/)" >&2
  exit 1
}

collect_script="$repo_root/scripts/benchmarks/collect-results.py"
summary_script="$repo_root/scripts/benchmarks/generate-summary.py"

if [ ! -f "$collect_script" ]; then
  echo "ERROR: collect-results.py not found at $collect_script" >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────
# Build model list
# ──────────────────────────────────────────────────────────────────────
models=()

if $all_models; then
  echo "Discovering models..."
  mlx-discover --quiet 2>/dev/null || true

  hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"
  total_bytes=$(sysctl -n hw.memsize)
  total_gb=$(( total_bytes / 1073741824 ))
  available_gb=$(( total_gb - 20 ))

  # Non-generative model patterns to skip
  skip_pattern="FLUX|whisper|OCR|Embedding|TTS|GGUF|clip|siglip|reranker|gte-|bge-"

  for model_dir in "$hf_home/hub"/models--*; do
    [ -d "$model_dir" ] || continue
    dir_name=$(basename "$model_dir")
    model_id="${dir_name#models--}"
    model_id="${model_id//--//}"

    # Skip non-generative
    if echo "$model_id" | grep -qEi "$skip_pattern"; then
      continue
    fi

    # Memory fit check
    est_gb=$(du -sk "$model_dir" | awk '{print int($1 / 1048576 * 1.3 + 0.5)}')
    if [ "$est_gb" -le "$available_gb" ]; then
      models+=("$model_id")
    fi
  done

  if [ ${#models[@]} -eq 0 ]; then
    echo "ERROR: No fitting models found" >&2
    exit 1
  fi
  echo "Found ${#models[@]} models to benchmark"
elif [ -n "$model" ]; then
  models=("$model")
else
  if [ -z "${MLX_DEFAULT_MODEL:-}" ]; then
    echo "ERROR: No model specified and MLX_DEFAULT_MODEL not set" >&2
    echo "Use --model <id> or --all-models" >&2
    exit 1
  fi
  models=("$MLX_DEFAULT_MODEL")
fi

# ──────────────────────────────────────────────────────────────────────
# Split suite list
# ──────────────────────────────────────────────────────────────────────
IFS=',' read -ra suite_list <<< "$suites"

# ──────────────────────────────────────────────────────────────────────
# Run benchmarks
# ──────────────────────────────────────────────────────────────────────
total_runs=$(( ${#models[@]} * ${#suite_list[@]} ))
run_count=0
failed=0

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  MLX Benchmark Run"
echo "  Models: ${#models[@]}  |  Suites: ${#suite_list[@]}  |  Total: $total_runs"
echo "═══════════════════════════════════════════════════════"
echo ""

for m in "${models[@]}"; do
  echo "────────────────────────────────────────────────────"
  echo "  Model: $m"
  echo "────────────────────────────────────────────────────"

  if ! $dry_run; then
    # Switch to model (includes preflight + auto-discover)
    echo "Switching to $m..."
    if ! mlx-switch "$m" 2>&1; then
      echo "WARNING: Failed to switch to $m — skipping" >&2
      failed=$(( failed + ${#suite_list[@]} ))
      run_count=$(( run_count + ${#suite_list[@]} ))
      continue
    fi

    # Wait for model to be ready
    echo "Waiting for model to become ready..."
    if ! mlx-wait 180 2>&1; then
      echo "WARNING: Model $m did not become ready — skipping" >&2
      failed=$(( failed + ${#suite_list[@]} ))
      run_count=$(( run_count + ${#suite_list[@]} ))
      continue
    fi

    # Warmup requests
    if [ "$warmup" -gt 0 ]; then
      echo "Warming up ($warmup requests)..."
      api="${MLX_API_URL:-http://127.0.0.1:11434/v1}"
      for i in $(seq 1 "$warmup"); do
        curl -sf "$api/chat/completions" \
          -H "Content-Type: application/json" \
          --max-time 60 \
          -d "{\"model\": \"$m\", \"messages\": [{\"role\": \"user\", \"content\": \"warmup $i\"}], \"max_tokens\": 10}" \
          > /dev/null 2>&1 || true
      done
    fi
  fi

  for s in "${suite_list[@]}"; do
    run_count=$(( run_count + 1 ))
    echo "  [$run_count/$total_runs] Suite: $s"

    cmd=(uv run "$collect_script" --suite "$s" --model "$m")
    if $dry_run; then
      cmd+=(--dry-run)
    fi
    if [ -n "$output_dir" ]; then
      cmd+=(--output-dir "$output_dir")
    fi

    if "${cmd[@]}" 2>&1 | tail -1; then
      echo "  ✓ $s complete"
    else
      echo "  ✗ $s failed" >&2
      failed=$(( failed + 1 ))
    fi
  done

  # Sleep between models for memory reclamation
  if ! $dry_run && [ ${#models[@]} -gt 1 ]; then
    echo "  Waiting 10s for memory reclamation..."
    sleep 10
  fi
done

# ──────────────────────────────────────────────────────────────────────
# Regenerate docs
# ──────────────────────────────────────────────────────────────────────
if [ -f "$summary_script" ]; then
  echo ""
  echo "Regenerating benchmark summary..."
  uv run "$summary_script" 2>&1 || echo "WARNING: Summary generation failed" >&2
fi

# ──────────────────────────────────────────────────────────────────────
# Final report
# ──────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Benchmark Complete"
echo "  Passed: $(( total_runs - failed ))/$total_runs"
if [ "$failed" -gt 0 ]; then
  echo "  Failed: $failed"
fi
echo "═══════════════════════════════════════════════════════"

exit $(( failed > 0 ? 1 : 0 ))
