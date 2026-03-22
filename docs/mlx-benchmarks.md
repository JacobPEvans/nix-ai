<!-- cspell:words TTFT hellaswag -->
# MLX Benchmark Suite

Automated performance and accuracy tracking for the vllm-mlx inference server.

## Quick Start

```bash
# Run the full suite (throughput + TTFT + accuracy)
mlx-bench-all

# Run with markdown report to stdout
mlx-bench-all --report

# Skip accuracy tests for a faster run
mlx-bench-all --skip-accuracy

# Custom token lengths
mlx-bench-all --tokens 256,512,1024
```

Results are saved as JSON to `~/.local/share/mlx-bench/results/<timestamp>.json`.

## What It Runs

All phases use native upstream tools — no custom benchmark logic:

| Phase | Native Tool | What It Measures |
|-------|-------------|------------------|
| Throughput | `curl` → vllm-mlx API | tok/s at multiple output lengths |
| TTFT | `curl` timing | Cold vs warm time-to-first-token, cache speedup |
| Accuracy | `lm-eval` (EleutherAI) | Tool-calling decisions, code review bug detection |

## Individual Tools

The suite is composed of these standalone commands, each a thin wrapper
around an upstream tool:

```bash
# Throughput (vllm-mlx-bench — loads model directly)
mlx-bench --model $MLX_DEFAULT_MODEL --max-tokens 512

# Engine benchmark (vllm-mlx bench — cache/batching knobs)
mlx-bench-engine --model $MLX_DEFAULT_MODEL

# Raw MLX perf (mlx_lm.benchmark — bypasses vllm-mlx overhead)
mlx-bench-raw --model $MLX_DEFAULT_MODEL --max-tokens 512

# Accuracy eval (lm-eval harness — standardized tasks)
mlx-eval --tasks hellaswag --limit 100
```

## Custom Eval Tasks

Two project-specific lm-eval tasks are bundled in `modules/mlx/eval-tasks/`:

- **mlx_tool_calling** — 4 scenarios testing tool-call vs. abstention decisions
- **mlx_code_review** — 3 code snippets with planted bugs (off-by-one, null check, SQL injection)

These are standard lm-eval YAML task definitions with JSONL datasets. Add new
test cases by appending to the `.jsonl` files.

## JSON Output Schema

```json
{
  "timestamp": "2026-03-22T01:00:00Z",
  "system": {
    "model": "mlx-community/Qwen3.5-122B-A10B-4bit",
    "api": "http://127.0.0.1:11434/v1",
    "baseline_mem_gb": "65.0",
    "final_mem_gb": "65.0"
  },
  "throughput": [
    {"max_tokens": 50, "completion_tokens": 50, "elapsed_s": 7.78, "tok_s": 6.4},
    {"max_tokens": 512, "completion_tokens": 512, "elapsed_s": 19.04, "tok_s": 26.9}
  ],
  "ttft": {
    "cold_runs": [0.55, 0.58, 0.57],
    "warm_runs": [0.65, 0.66, 0.65],
    "cold_avg_s": 0.566,
    "warm_avg_s": 0.652,
    "cache_speedup": 0.9
  },
  "accuracy": {
    "tasks": {
      "mlx_tool_calling": {"tool_accuracy": 1.0},
      "mlx_code_review": {"bug_detection_rate": 1.0}
    }
  }
}
```

## Historical Results

Previous manually-recorded benchmark results (2026-03-20 through 2026-03-22)
are preserved in git history. Key findings from those runs:

- **Throughput**: 25-49 tok/s depending on output length and tool-calling mode
- **TTFT**: 0.29-2.0s cold, prefix cache provides 2.6-3.9x speedup (when `<think>` tokens don't invalidate)
- **Tool calling**: 4/4 correct decisions, 100% code review bug detection
- **Memory**: Stable at 65 GB RSS, zero swap on 128 GB M4 Max
- **OOM guardrails**: Zero performance cost (ProcessType=Background, HardResourceLimits are metadata-only)
