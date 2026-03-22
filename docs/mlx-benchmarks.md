<!-- cspell:words TTFT hellaswag -->
# MLX Benchmark Results

Performance tracking for the vllm-mlx inference server across configuration changes.

## System

- **Hardware**: Apple M4 Max, 128 GB unified memory
- **OS**: macOS 26.3.1 (Tahoe)
- **Server**: vllm-mlx 0.2.6 (OpenAI-compatible API on port 11434)
- **Model**: mlx-community/Qwen3.5-122B-A10B-4bit (~65 GB on disk)

## How to Run

All benchmark tools are installed via nix-ai's MLX module. Run from any
terminal with the nix-ai home-manager profile active.

```bash
# Verify server is running and model is loaded
mlx-status

# Check model fits in memory before loading
mlx-preflight mlx-community/Qwen3.5-122B-A10B-4bit

# List all downloaded models with memory fit status
mlx-models

# Throughput benchmark (raw MLX, bypasses vllm-mlx overhead)
mlx-bench-raw --model mlx-community/Qwen3.5-122B-A10B-4bit --max-tokens 512

# Throughput benchmark (through vllm-mlx server)
mlx-bench --model mlx-community/Qwen3.5-122B-A10B-4bit --max-tokens 512

# Engine benchmark with cache/batching knobs
mlx-bench-engine --model mlx-community/Qwen3.5-122B-A10B-4bit

# Quick API latency test (TTFT)
# Run twice: first = cold TTFT, second = warm TTFT (prefix cache hit)
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"mlx-community/Qwen3.5-122B-A10B-4bit",
       "messages":[{"role":"user","content":"Hello"}],
       "max_tokens":1,"temperature":0}' \
  -o /dev/null -w "TTFT: %{time_total}s\n"

# Accuracy evaluation (lm-eval harness against live API)
mlx-eval --tasks hellaswag --limit 100
```

## Results

### 2026-03-22 — Post-OOM Guardrails (PR #273 merged)

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB.
System: macOS 26.3.1, vllm-mlx 0.2.6.

| Test | Metric | Value | Notes |
|------|--------|-------|-------|
| Short gen (50 tok) | tok/s | 23.6 | Single request, warm server |
| Long gen (512 tok) | tok/s | 44.5 | Single request |
| TTFT cold | latency | 1.13s | Unique prompt, no prefix cache |
| TTFT warm | latency | 0.29s | Repeated prompt, prefix cache hit |
| Cache speedup | ratio | 3.9x | warm vs cold TTFT |

### 2026-03-20 — Initial Baseline (Issue #257)

Config: KV cache uncapped (~25.6 GB auto-detect), no ProcessType, no resource limits.
System: macOS 26.3.0, vllm-mlx 0.2.6.

| Test | Metric | Value | Notes |
|------|--------|-------|-------|
| Short gen (50 tok) | tok/s | 5.5 | Likely includes cold TTFT in measurement |
| Long gen (512 tok) | tok/s | 43.3 | Single request |
| TTFT cold | latency | 2.0s | First request |
| TTFT warm | latency | 0.76s | Cached |
| Cache speedup | ratio | 2.6x | warm vs cold TTFT |

### Observations

- **Long generation throughput is stable** at ~44 tok/s across both configs. The 16 GB
  KV cache cap (down from 25.6 GB uncapped) has no measurable impact on single-request
  throughput — the model is bandwidth-bound, not cache-bound.
- **Short generation improved dramatically** (5.5 → 23.6 tok/s). The March 20 baseline
  likely measured end-to-end latency including cold TTFT, inflating per-token cost. The
  March 22 test measured on a warm server.
- **TTFT improved** across both cold (2.0s → 1.13s) and warm (0.76s → 0.29s). Possible
  causes: server warm-up state, prefix cache efficiency with smaller cache, or measurement
  methodology differences.
- **OOM guardrails have zero performance cost.** ProcessType=Background and
  HardResourceLimits are metadata-only — no runtime overhead.
