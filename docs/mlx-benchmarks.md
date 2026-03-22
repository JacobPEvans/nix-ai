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

### 2026-03-22 — Memory-Tracked Throughput Sweep

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB.
System: macOS 26.3.1, vllm-mlx 0.2.6, PID 1438.

Sequential generation tests with memory snapshots via `footprint` (process)
and `vm_stat` (system). All values in GB unless noted.

#### Throughput

| Test | Tokens | Time | tok/s |
|------|--------|------|-------|
| Short gen | 50 | 1.95s | 25.6 |
| Medium gen | 256 | 5.39s | 47.5 |
| Long gen | 512 | 10.43s | 49.1 |
| Rapid fire 1/3 | 50 | 1.32s | 37.9 |
| Rapid fire 2/3 | 50 | 1.27s | 39.4 |
| Rapid fire 3/3 | 50 | 1.22s | 41.0 |

#### Memory Timeline

| Time | Phase | vllm RSS (GB) | vllm Peak (GB) | Free (GB) | Active (GB) | Wired (GB) | Compressed (GB) | Swap |
|------|-------|---------------|----------------|-----------|-------------|------------|-----------------|------|
| 23:24:05 | idle (pre-test) | 65 | 65 | 0.9 | 58.9 | 5.7 | 2.7 | 0.00M |
| 23:24:07 | after short gen (50 tok) | 65 | 65 | 0.7 | 22.1 | 69.8 | 2.7 | 0.00M |
| 23:24:13 | after medium gen (256 tok) | 65 | 65 | 1.4 | 21.7 | 70.7 | 2.6 | 0.00M |
| 23:24:23 | after long gen (512 tok) | 65 | 65 | 1.7 | 22.5 | 70.6 | 2.6 | 0.00M |
| 23:24:28 | after 3x rapid short gen | 65 | 65 | 1.5 | 22.3 | 71.3 | 2.6 | 0.00M |
| 23:24:33 | idle (post-test, +5s) | 65 | 65 | 2.2 | 86.3 | 5.0 | 2.6 | 0.00M |

#### Memory Observations

- **vllm-mlx RSS is constant at 65 GB** throughout all tests — no memory leaks, no
  growth from KV cache accumulation. Peak never exceeds baseline.
- **Wired memory spikes during generation** (5.7 → 71.3 GB) as MLX allocates Metal
  GPU buffers for KV cache and compute. These return to active memory after generation
  completes (visible in the post-test idle row: wired drops back to 5.0 GB).
- **Zero swap throughout** — the 16 GB KV cache cap keeps total memory well within
  the 128 GB physical limit.
- **Throughput increases with token count**: 25.6 tok/s (50 tok) → 49.1 tok/s (512 tok).
  Short generations are TTFT-dominated; longer generations amortize prefill cost and
  approach the memory-bandwidth ceiling (~50 tok/s for this model).

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
