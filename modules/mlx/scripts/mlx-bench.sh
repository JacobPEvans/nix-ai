#!/usr/bin/env bash
# mlx-bench — benchmark vllm-mlx throughput, accuracy, latency, and prefix-cache
#
# Modes:
#   --throughput   (default) Measure tok/s at different concurrency levels
#   --accuracy     Run factual Q&A prompts, score correctness
#   --latency      Measure TTFT and P50/P95/P99 response times
#   --prefix-cache Repeated system prompt, measure cache hit speedup
#   --sweep        Run all modes in sequence, output combined report
#
# Options:
#   --model MODEL  Override model (uses $MLX_DEFAULT_MODEL by default)
#   --jobs N       Concurrency level for throughput mode (default: 1)
#   --tokens N     Max tokens per request (overrides per-prompt defaults)

set -euo pipefail

# ---- Cleanup ----
BENCH_TMPDIR=""
cleanup() { [[ -n "$BENCH_TMPDIR" ]] && rm -rf "$BENCH_TMPDIR"; }
trap cleanup EXIT

# ---- Configuration ----
API_URL="${MLX_API_URL:-http://127.0.0.1:11434/v1}"
MODEL="${MLX_DEFAULT_MODEL:-}"
JOBS=1
MAX_TOKENS_OVERRIDE=""
MODE="throughput"

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --throughput) MODE="throughput"; shift ;;
    --accuracy)   MODE="accuracy"; shift ;;
    --latency)    MODE="latency"; shift ;;
    --prefix-cache) MODE="prefix-cache"; shift ;;
    --sweep)      MODE="sweep"; shift ;;
    --model)      MODEL="$2"; shift 2 ;;
    --jobs)       JOBS="$2"; shift 2 ;;
    --tokens)     MAX_TOKENS_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: mlx-bench [--throughput|--accuracy|--latency|--prefix-cache|--sweep]"
      echo "                 [--model MODEL] [--jobs N] [--tokens N]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  echo "Error: No model specified. Set MLX_DEFAULT_MODEL or use --model." >&2
  exit 1
fi

# ---- Timing helper (resolved once) ----
if date +%s%N > /dev/null 2>&1 && [[ "$(date +%s%N)" != *N* ]]; then
  now_ns() { date +%s%N; }
else
  now_ns() { python3 -c 'import time; print(int(time.time_ns()))'; }
fi

# Elapsed seconds between two nanosecond timestamps
elapsed_s() { echo "$1 $2" | awk '{printf "%.3f", ($2-$1)/1000000000}'; }

# Elapsed milliseconds between two nanosecond timestamps
elapsed_ms() { echo "$1 $2" | awk '{printf "%.1f", ($2-$1)/1000000}'; }

# ---- Helpers ----

# Send a chat completion request, return the full JSON response
chat_completion() {
  local prompt="$1"
  local max_tokens="$2"
  local system_prompt="${3:-}"

  local messages
  if [[ -n "$system_prompt" ]]; then
    messages=$(jq -n --arg sys "$system_prompt" --arg usr "$prompt" \
      '[{"role":"system","content":$sys},{"role":"user","content":$usr}]')
  else
    messages=$(jq -n --arg usr "$prompt" \
      '[{"role":"user","content":$usr}]')
  fi

  curl -sf "${API_URL}/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg model "$MODEL" \
      --argjson max_tokens "$max_tokens" \
      --argjson messages "$messages" \
      '{model:$model,messages:$messages,max_tokens:$max_tokens,temperature:0}')"
}

# Get completion text from response
get_content() {
  local response="$1"
  echo "$response" | jq -r '.choices[0].message.content // ""'
}

# Ensure tmpdir exists (created once, cleaned up by trap)
ensure_tmpdir() {
  if [[ -z "$BENCH_TMPDIR" ]]; then
    BENCH_TMPDIR=$(mktemp -d)
  fi
}

# ---- Prompt Definitions ----
# Arrays are positionally coupled — keep lengths in sync.

# Throughput prompts (varied complexity)
declare -a THROUGHPUT_PROMPTS THROUGHPUT_TOKENS THROUGHPUT_LABELS
THROUGHPUT_PROMPTS=(
  "Write a Python function that implements binary search on a sorted list. Include type hints and a docstring explaining the algorithm."
  "Review this function for bugs: def merge_sorted(a, b): result = []; i = j = 0; while i < len(a) and j < len(b): if a[i] <= b[j]: result.append(a[i]); i += 1; else: result.append(b[j]); j += 1; return result"
  "Summarize the key points: Machine learning models require careful evaluation to ensure they generalize well to unseen data. Cross-validation is a technique that partitions data into complementary subsets, training on one and validating on another. K-fold cross-validation divides data into k equal parts, using each as a validation set exactly once. This provides a more reliable estimate of model performance than a single train-test split, especially with limited data."
  "What is the time complexity of quicksort in the average case?"
)
THROUGHPUT_TOKENS=(256 128 128 64)
THROUGHPUT_LABELS=("code_gen" "code_review" "summarization" "factual_qa")

# Accuracy prompts with expected keywords
declare -a ACCURACY_PROMPTS ACCURACY_TOKENS ACCURACY_KEYWORDS ACCURACY_LABELS
ACCURACY_PROMPTS=(
  "What is the time complexity of quicksort in the average case? Answer briefly."
  "A farmer has 17 sheep. All but 9 die. How many are left? Answer with just the number."
  "What does HTTP status code 404 mean? Answer in one sentence."
  "In Python, what does the 'yield' keyword do? Answer briefly."
  "What is the chemical symbol for gold? Answer with just the symbol."
  "How many bits are in a byte? Answer with just the number."
  "What sorting algorithm has O(n) best-case time complexity? Name one."
  "What protocol does HTTPS use for encryption? Answer briefly."
  "What is 2^10? Answer with just the number."
  "In git, what command creates a new branch? Answer briefly."
)
ACCURACY_TOKENS=(64 32 64 64 16 16 32 32 16 32)
ACCURACY_KEYWORDS=(
  "n log n|nlogn|n\\*log|O(n log n)"
  "\\b9\\b"
  "not found|does not exist|resource.*not.*found"
  "generator|iterator|pause|suspend|lazy"
  "\\bAu\\b"
  "\\b8\\b"
  "insertion|timsort|bucket|counting|radix"
  "TLS|SSL|Transport Layer Security"
  "\\b1024\\b"
  "branch|checkout -b|switch -c"
)
ACCURACY_LABELS=(
  "quicksort_complexity" "sheep_riddle" "http_404" "python_yield"
  "gold_symbol" "bits_byte" "linear_sort" "https_protocol"
  "power_of_2" "git_branch"
)

# Validate parallel arrays have matching lengths
validate_arrays() {
  if [[ ${#THROUGHPUT_PROMPTS[@]} -ne ${#THROUGHPUT_TOKENS[@]} ]] ||
     [[ ${#THROUGHPUT_PROMPTS[@]} -ne ${#THROUGHPUT_LABELS[@]} ]]; then
    echo "Error: THROUGHPUT arrays have mismatched lengths" >&2
    exit 1
  fi
  if [[ ${#ACCURACY_PROMPTS[@]} -ne ${#ACCURACY_TOKENS[@]} ]] ||
     [[ ${#ACCURACY_PROMPTS[@]} -ne ${#ACCURACY_KEYWORDS[@]} ]] ||
     [[ ${#ACCURACY_PROMPTS[@]} -ne ${#ACCURACY_LABELS[@]} ]]; then
    echo "Error: ACCURACY arrays have mismatched lengths" >&2
    exit 1
  fi
}

# Prefix-cache system prompt (~500 tokens)
PREFIX_SYSTEM_PROMPT="You are a senior software engineer specializing in distributed systems, cloud architecture, and performance optimization. You have extensive experience with Kubernetes, Terraform, Ansible, and infrastructure-as-code practices. Your expertise spans across multiple programming languages including Python, Go, Rust, and TypeScript. You follow best practices for code review, testing, and CI/CD pipelines. When answering questions, you provide concise, actionable advice with code examples when relevant. You prioritize security, reliability, and maintainability in all recommendations. You are familiar with observability tools like Prometheus, Grafana, and OpenTelemetry. You understand the tradeoffs between different architectural patterns including microservices, monoliths, and serverless approaches. You always consider cost optimization and operational complexity when making recommendations. Your responses should be practical and grounded in real-world production experience."

# ---- Mode Implementations ----

run_throughput() {
  local jobs="${1:-$JOBS}"
  echo "# Throughput benchmark (jobs=$jobs, model=$MODEL)" >&2

  for i in "${!THROUGHPUT_PROMPTS[@]}"; do
    local prompt="${THROUGHPUT_PROMPTS[$i]}"
    local max_tokens="${MAX_TOKENS_OVERRIDE:-${THROUGHPUT_TOKENS[$i]}}"
    local label="${THROUGHPUT_LABELS[$i]}"

    if [[ "$jobs" -eq 1 ]]; then
      local start_ns end_ns wall_s response completion_tokens tok_s
      start_ns=$(now_ns)
      response=$(chat_completion "$prompt" "$max_tokens")
      end_ns=$(now_ns)
      wall_s=$(elapsed_s "$start_ns" "$end_ns")
      completion_tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
      if [[ "$completion_tokens" -gt 0 ]]; then
        tok_s=$(echo "$completion_tokens $wall_s" | awk '{printf "%.1f", $1/$2}')
      else
        tok_s="0"
      fi

      jq -n --arg test "throughput" --arg label "$label" \
        --argjson jobs "$jobs" --argjson tokens "$completion_tokens" \
        --argjson tok_s "$tok_s" --argjson wall_s "$wall_s" \
        --arg model "$MODEL" \
        '{test:$test,label:$label,jobs:$jobs,tokens:$tokens,tok_s:($tok_s|tonumber),wall_s:($wall_s|tonumber),model:$model}'
    else
      ensure_tmpdir
      local start_ns end_ns pids=()
      start_ns=$(now_ns)

      for j in $(seq 1 "$jobs"); do
        chat_completion "$prompt" "$max_tokens" > "$BENCH_TMPDIR/resp_${label}_${j}.json" &
        pids+=($!)
      done

      local failed=0
      for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
          failed=$((failed + 1))
        fi
      done
      if [[ "$failed" -gt 0 ]]; then
        echo "Warning: $failed/$jobs requests failed for $label" >&2
      fi

      end_ns=$(now_ns)
      local wall_s total_tokens
      wall_s=$(elapsed_s "$start_ns" "$end_ns")
      total_tokens=0
      for j in $(seq 1 "$jobs"); do
        local t
        t=$(jq -r '.usage.completion_tokens // 0' "$BENCH_TMPDIR/resp_${label}_${j}.json" 2>/dev/null || echo 0)
        total_tokens=$((total_tokens + t))
      done
      local aggregate_tok_s
      aggregate_tok_s=$(echo "$total_tokens $wall_s" | awk '{printf "%.1f", $1/$2}')

      jq -n --arg test "throughput" --arg label "$label" \
        --argjson jobs "$jobs" --argjson tokens "$total_tokens" \
        --argjson tok_s "$aggregate_tok_s" --argjson wall_s "$wall_s" \
        --arg model "$MODEL" \
        '{test:$test,label:$label,jobs:$jobs,tokens:$tokens,tok_s:($tok_s|tonumber),wall_s:($wall_s|tonumber),model:$model}'
    fi
  done
}

run_accuracy() {
  echo "# Accuracy benchmark (model=$MODEL)" >&2
  local correct=0
  local total=${#ACCURACY_PROMPTS[@]}

  for i in "${!ACCURACY_PROMPTS[@]}"; do
    local prompt="${ACCURACY_PROMPTS[$i]}"
    local max_tokens="${MAX_TOKENS_OVERRIDE:-${ACCURACY_TOKENS[$i]}}"
    local keywords="${ACCURACY_KEYWORDS[$i]}"
    local label="${ACCURACY_LABELS[$i]}"

    local response content is_correct
    response=$(chat_completion "$prompt" "$max_tokens")
    content=$(get_content "$response")

    if echo "$content" | grep -iqE "$keywords"; then
      is_correct=true
      correct=$((correct + 1))
    else
      is_correct=false
    fi

    jq -n --arg test "accuracy" --arg label "$label" \
      --argjson correct "$is_correct" \
      --arg response "$content" --arg expected "$keywords" \
      --arg model "$MODEL" \
      '{test:$test,label:$label,correct:$correct,response:$response,expected_pattern:$expected,model:$model}'
  done

  local pct
  pct=$(echo "$correct $total" | awk '{printf "%.1f", $1/$2*100}')
  jq -n --arg test "accuracy_summary" \
    --argjson correct "$correct" --argjson total "$total" \
    --argjson pct "$pct" --arg model "$MODEL" \
    '{test:$test,correct:$correct,total:$total,pct:($pct|tonumber),model:$model}'
}

run_latency() {
  local iterations=10
  echo "# Latency benchmark ($iterations iterations, model=$MODEL)" >&2

  ensure_tmpdir
  local prompt="What is 2+2? Answer with just the number."
  local max_tokens="${MAX_TOKENS_OVERRIDE:-16}"

  for i in $(seq 1 "$iterations"); do
    local start_ns end_ns
    start_ns=$(now_ns)
    chat_completion "$prompt" "$max_tokens" > /dev/null
    end_ns=$(now_ns)
    elapsed_ms "$start_ns" "$end_ns" >> "$BENCH_TMPDIR/latencies.txt"
  done

  # Calculate percentiles
  local sorted p50 p95 p99 avg
  sorted=$(sort -n "$BENCH_TMPDIR/latencies.txt")
  p50=$(echo "$sorted" | awk "NR==$(( (iterations + 1) / 2 )){print}")
  p95=$(echo "$sorted" | awk "NR==$(( (iterations * 95 + 99) / 100 )){print}")
  p99=$(echo "$sorted" | awk "NR==$iterations{print}")
  avg=$(awk '{s+=$1} END{printf "%.1f", s/NR}' "$BENCH_TMPDIR/latencies.txt")

  jq -n --arg test "latency" \
    --argjson iterations "$iterations" \
    --argjson avg_ms "$avg" --argjson p50_ms "$p50" \
    --argjson p95_ms "$p95" --argjson p99_ms "$p99" \
    --arg model "$MODEL" \
    '{test:$test,iterations:$iterations,avg_ms:($avg_ms|tonumber),p50_ms:($p50_ms|tonumber),p95_ms:($p95_ms|tonumber),p99_ms:($p99_ms|tonumber),model:$model}'
}

run_prefix_cache() {
  local iterations=5
  echo "# Prefix-cache benchmark ($iterations iterations, model=$MODEL)" >&2

  local prompt="Given your expertise, what is the single most important thing to monitor in a Kubernetes cluster?"
  local max_tokens="${MAX_TOKENS_OVERRIDE:-64}"

  # Cold run (no cache)
  local start_ns end_ns cold_ms
  start_ns=$(now_ns)
  chat_completion "$prompt" "$max_tokens" "$PREFIX_SYSTEM_PROMPT" > /dev/null
  end_ns=$(now_ns)
  cold_ms=$(elapsed_ms "$start_ns" "$end_ns")

  # Warm runs (same system prompt, should hit prefix cache)
  local warm_total=0
  for i in $(seq 1 "$iterations"); do
    start_ns=$(now_ns)
    chat_completion "$prompt" "$max_tokens" "$PREFIX_SYSTEM_PROMPT" > /dev/null
    end_ns=$(now_ns)
    local warm_ms
    warm_ms=$(elapsed_ms "$start_ns" "$end_ns")
    warm_total=$(echo "$warm_total $warm_ms" | awk '{printf "%.1f", $1+$2}')
  done

  local warm_avg speedup
  warm_avg=$(echo "$warm_total $iterations" | awk '{printf "%.1f", $1/$2}')
  speedup=$(echo "$cold_ms $warm_avg" | awk '{if($2>0) printf "%.2f", $1/$2; else print "0"}')

  jq -n --arg test "prefix_cache" \
    --argjson cold_ms "$cold_ms" --argjson warm_avg_ms "$warm_avg" \
    --argjson speedup "$speedup" --argjson iterations "$iterations" \
    --arg model "$MODEL" \
    '{test:$test,cold_ms:($cold_ms|tonumber),warm_avg_ms:($warm_avg_ms|tonumber),speedup:($speedup|tonumber),iterations:$iterations,model:$model}'
}

run_sweep() {
  echo "# Full sweep benchmark (model=$MODEL)" >&2
  echo "---" >&2

  echo "## Throughput (single)" >&2
  run_throughput 1

  if [[ "$JOBS" -gt 1 ]]; then
    echo "## Throughput (jobs=$JOBS)" >&2
    run_throughput "$JOBS"
  fi

  echo "## Accuracy" >&2
  run_accuracy

  echo "## Latency" >&2
  run_latency

  echo "## Prefix Cache" >&2
  run_prefix_cache
}

# ---- Main ----

# Verify server is reachable
if ! curl -sf "${API_URL}/models" > /dev/null 2>&1; then
  echo "Error: vllm-mlx server not reachable at ${API_URL}" >&2
  echo "Start the server or check MLX_API_URL." >&2
  exit 1
fi

validate_arrays

echo "# mlx-bench: mode=$MODE model=$MODEL jobs=$JOBS" >&2
echo "---" >&2

case "$MODE" in
  throughput)   run_throughput "$JOBS" ;;
  accuracy)     run_accuracy ;;
  latency)      run_latency ;;
  prefix-cache) run_prefix_cache ;;
  sweep)        run_sweep ;;
esac
