# MLX Benchmark Results

Performance tracking for the vllm-mlx inference server across configuration changes.

## System

- **Hardware**: Apple M4 Max, 128 GB unified memory
- **OS**: macOS Tahoe 26.3.0
- **Server**: vllm-mlx 0.2.6 (OpenAI-compatible API on port 11434)
- **Model**: mlx-community/Qwen3.5-122B-A10B-4bit (~65 GB on disk)

## Results

### 2026-03-22 — Post-OOM Guardrails (PR #273 merged)

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB.

| Test | Metric | Value | Notes |
|------|--------|-------|-------|
| Short gen (50 tok) | tok/s | 23.6 | Single request, warm server |
| Long gen (512 tok) | tok/s | 44.5 | Single request |
| TTFT cold | latency | 1.13s | Unique prompt, no prefix cache |
| TTFT warm | latency | 0.29s | Repeated prompt, prefix cache hit |
| Cache speedup | ratio | 3.9x | warm vs cold TTFT |

### 2026-03-20 — Initial Baseline (Issue #257)

Config: KV cache uncapped (~25.6 GB auto-detect), no ProcessType, no resource limits.

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
