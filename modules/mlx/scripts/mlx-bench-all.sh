# mlx-bench-all — run the full MLX benchmark suite and log structured results.
#
# Orchestrates native upstream tools:
#   - vllm-mlx API via curl (throughput, TTFT)
#   - lm-eval (accuracy via EleutherAI harness)
#
# Results: JSON to ~/.local/share/mlx-bench/results/<timestamp>.json
# Report:  --report flag emits markdown summary to stdout
#
# Usage: mlx-bench-all [--report] [--skip-accuracy] [--tokens 50,256,512]

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
api="${MLX_API_URL:?MLX_API_URL not set}"
model="${MLX_DEFAULT_MODEL:?MLX_DEFAULT_MODEL not set}"
results_dir="${MLX_BENCH_RESULTS:-${XDG_DATA_HOME:-$HOME/.local/share}/mlx-bench/results}"
eval_tasks_dir="${MLX_EVAL_TASKS_DIR:?MLX_EVAL_TASKS_DIR not set — this should be set by the Nix wrapper}"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
file_ts=$(date -u +"%Y-%m-%d-%H%M%S")

report=false
skip_accuracy=false
token_lengths="50,100,256,512,1024"

while [[ $# -gt 0 ]]; do
  case $1 in
    --report) report=true; shift ;;
    --skip-accuracy) skip_accuracy=true; shift ;;
    --tokens) token_lengths="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: mlx-bench-all [--report] [--skip-accuracy] [--tokens 50,256,512]"
      echo ""
      echo "Runs the full MLX benchmark suite using native upstream tools."
      echo "Results saved to: $results_dir/<timestamp>.json"
      echo ""
      echo "Options:"
      echo "  --report          Print markdown summary to stdout"
      echo "  --skip-accuracy   Skip lm-eval accuracy tests (faster)"
      echo "  --tokens LIST     Comma-separated output token lengths (default: 50,100,256,512,1024)"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$results_dir"
result_file="$results_dir/$file_ts.json"

echo "=== MLX Benchmark Suite ==="
echo "Model:   $model"
echo "API:     $api"
echo "Results: $result_file"
echo ""

# ---------------------------------------------------------------------------
# Pre-flight: wait for server, capture baseline
# ---------------------------------------------------------------------------
echo "--- Pre-flight ---"
mlx-wait 30

baseline_mem="unknown"
if mem_line=$(mlx-status 2>/dev/null); then
  baseline_mem=$(echo "$mem_line" | sed -n 's/.*mem=\([0-9.]*\).*/\1/p' || echo "unknown")
fi

# ---------------------------------------------------------------------------
# Phase 1: Throughput (vllm-mlx-bench)
# ---------------------------------------------------------------------------
echo ""
echo "--- Phase 1: Throughput ---"
IFS=',' read -ra lengths <<< "$token_lengths"
throughput_json="[]"

for toks in "${lengths[@]}"; do
  echo "  Generating $toks tokens..."

  # Use curl's built-in timing (portable, works on macOS)
  tmpfile=$(mktemp)
  elapsed_s=$(curl -sf -o "$tmpfile" -w "%{time_total}" "$api/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Write a detailed essay about artificial intelligence.\"}],\"max_tokens\":$toks,\"temperature\":0}" \
    2>/dev/null) || { echo "  FAILED (curl error)"; rm -f "$tmpfile"; continue; }

  response=$(cat "$tmpfile")
  rm -f "$tmpfile"

  completion_tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
  tok_s=$(echo "scale=1; $completion_tokens / $elapsed_s" | bc 2>/dev/null || echo "0")

  echo "  $completion_tokens tokens in ${elapsed_s}s (${tok_s} tok/s)"

  entry=$(jq -n --argjson max "$toks" --argjson actual "$completion_tokens" \
    --arg elapsed "$elapsed_s" --arg toks "$tok_s" \
    '{max_tokens: $max, completion_tokens: $actual, elapsed_s: ($elapsed | tonumber), tok_s: ($toks | tonumber)}')
  throughput_json=$(echo "$throughput_json" | jq --argjson e "$entry" '. + [$e]')
done

# ---------------------------------------------------------------------------
# Phase 2: TTFT (Time To First Token)
# ---------------------------------------------------------------------------
echo ""
echo "--- Phase 2: TTFT ---"
cold_runs="[]"
warm_runs="[]"

# 3 cold runs (unique prompts to avoid prefix cache)
for i in 1 2 3; do
  ttft=$(curl -sf -o /dev/null -w "%{time_total}" "$api/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Unique cold prompt $i $RANDOM $RANDOM\"}],\"max_tokens\":1,\"temperature\":0}" \
    2>/dev/null) || ttft="0"
  echo "  Cold $i: ${ttft}s"
  cold_runs=$(echo "$cold_runs" | jq --arg t "$ttft" '. + [($t | tonumber)]')
done

# 3 warm runs (same prompt for prefix cache hit)
warm_prompt="Repeat after me: benchmark warmup test"
for i in 1 2 3; do
  ttft=$(curl -sf -o /dev/null -w "%{time_total}" "$api/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$warm_prompt\"}],\"max_tokens\":1,\"temperature\":0}" \
    2>/dev/null) || ttft="0"
  echo "  Warm $i: ${ttft}s"
  warm_runs=$(echo "$warm_runs" | jq --arg t "$ttft" '. + [($t | tonumber)]')
done

cold_avg=$(echo "$cold_runs" | jq 'add / length')
warm_avg=$(echo "$warm_runs" | jq 'add / length')
cache_speedup=$(echo "scale=1; $cold_avg / $warm_avg" | bc 2>/dev/null || echo "0")

ttft_json=$(jq -n --argjson cold "$cold_runs" --argjson warm "$warm_runs" \
  --argjson cold_avg "$cold_avg" --argjson warm_avg "$warm_avg" \
  --arg speedup "$cache_speedup" \
  '{cold_runs: $cold, warm_runs: $warm, cold_avg_s: $cold_avg, warm_avg_s: $warm_avg, cache_speedup: ($speedup | tonumber)}')

# ---------------------------------------------------------------------------
# Phase 3: Accuracy (lm-eval harness)
# ---------------------------------------------------------------------------
accuracy_json="{}"
if [[ "$skip_accuracy" == "false" ]]; then
  echo ""
  echo "--- Phase 3: Accuracy (lm-eval) ---"
  accuracy_dir="$results_dir/$file_ts-accuracy"
  mkdir -p "$accuracy_dir"

  if mlx-eval \
    --tasks mlx_tool_calling,mlx_code_review \
    --include_path "$eval_tasks_dir" \
    --output_path "$accuracy_dir" \
    --log_samples 2>&1; then
    # Parse lm-eval results JSON
    if results_json=$(find "$accuracy_dir" -name "results.json" -type f | head -1) && [[ -n "$results_json" ]]; then
      accuracy_json=$(jq '{
        results_path: input_filename,
        tasks: .results | to_entries | map({
          key: .key,
          value: (.value | to_entries | map(select(.key | test("accuracy|detection"))) | from_entries)
        }) | from_entries
      }' "$results_json" 2>/dev/null || echo '{"note": "results generated, see accuracy dir"}')
    else
      accuracy_json="{\"note\": \"results generated at $accuracy_dir\"}"
    fi
  else
    echo "  lm-eval failed (non-fatal, continuing)"
    accuracy_json='{"error": "lm-eval failed"}'
  fi
else
  echo ""
  echo "--- Phase 3: Accuracy (skipped) ---"
fi

# ---------------------------------------------------------------------------
# Post-flight: final memory snapshot
# ---------------------------------------------------------------------------
echo ""
echo "--- Post-flight ---"
final_mem="unknown"
if mem_line=$(mlx-status 2>/dev/null); then
  final_mem=$(echo "$mem_line" | sed -n 's/.*mem=\([0-9.]*\).*/\1/p' || echo "unknown")
  echo "$mem_line"
fi

# ---------------------------------------------------------------------------
# Assemble & write JSON results
# ---------------------------------------------------------------------------
jq -n \
  --arg ts "$timestamp" \
  --arg model "$model" \
  --arg api "$api" \
  --arg baseline_mem "$baseline_mem" \
  --arg final_mem "$final_mem" \
  --argjson throughput "$throughput_json" \
  --argjson ttft "$ttft_json" \
  --argjson accuracy "$accuracy_json" \
  '{
    timestamp: $ts,
    system: {model: $model, api: $api, baseline_mem_gb: $baseline_mem, final_mem_gb: $final_mem},
    throughput: $throughput,
    ttft: $ttft,
    accuracy: $accuracy
  }' > "$result_file"

echo ""
echo "Results saved to: $result_file"

# ---------------------------------------------------------------------------
# Optional: markdown report
# ---------------------------------------------------------------------------
if [[ "$report" == "true" ]]; then
  echo ""
  echo "# MLX Benchmark Results — $timestamp"
  echo ""
  echo "**Model**: $model"
  echo ""
  echo "## Throughput"
  echo ""
  echo "| Max Tokens | Actual | Elapsed | tok/s |"
  echo "|-----------|--------|---------|-------|"
  echo "$throughput_json" | jq -r '.[] | "| \(.max_tokens) | \(.completion_tokens) | \(.elapsed_s)s | \(.tok_s) |"'
  echo ""
  echo "## TTFT (Time To First Token)"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Cold avg | ${cold_avg}s |"
  echo "| Warm avg | ${warm_avg}s |"
  echo "| Cache speedup | ${cache_speedup}x |"
  echo ""
  echo "## Memory"
  echo ""
  echo "| Phase | RSS (GB) |"
  echo "|-------|----------|"
  echo "| Baseline | $baseline_mem |"
  echo "| Final | $final_mem |"
fi
