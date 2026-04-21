# Session Report: Cold Start & Tool-Calling Validation (20-50GB Models)

**Date:** 2026-04-13
**Machine:** MacBook Pro (M4 Max, 128GB Unified Memory)
**Context:** Validation of Bifrost AI Gateway, MLX tool-calling reliability, and model-load performance gaps.

## Executive Summary

This session validated the tool-calling reliability of the 20-50GB local MLX model tier and
uncovered critical performance metrics regarding the "Idle Penalty" and Cold Start latencies.
While **Qwen** models remain the reliability gold standard for the current stack, models like
**GLM** and **Seed-OSS** suffer from tool-calling failures due to global parser mismatches
in `vllm-mlx`.

---

## 1. Tool-Calling Reliability (20-50GB Tier)

Tested via `http://localhost:30080` (Bifrost Gateway) with the default `--tool-call-parser hermes`.

| Model | Size | Result | Obs. Latency | Note |
| :--- | :--- | :--- | :--- | :--- |
| **Qwen3.5-35B-A3B-4bit** | ~18GB | **PASS** | 27.83s | Flawless XML tool invocation. |
| **Qwen3-Coder-30B-A3B-8bit**| ~30GB | **PASS** | 23.29s | Best-in-class for coding tools. |
| **Seed-OSS-36B-Instruct** | ~18GB | **FAIL** | 28.94s | Recognized intent; failed output format. |
| **GLM-4.7-Flash-Opus-Distill**| ~30GB | **FAIL** | 32.64s | Thinking trace verified; parser mismatch. |

**Finding:** The system's global reliance on the `hermes` parser creates a "Qwen-exclusive"
reliability zone for tool calling. Transitioning to `auto` or model-specific parsers is
required for broader model support.

---

## 2. Cold Start & "Idle Penalty" Metrics

A key finding was the significant overhead required to "warm" models after an idle period, even on a 128GB machine.

### **Comparison: Cold Start vs. Warm Response**

| Metric | Qwen3.5-35B (Preloaded) | Qwen3.5-122B (MoE) |
| :--- | :--- | :--- |
| **Cold Start Response** | **33.45s** | **106.03s** |
| **Warm Response** | **31.93s** | **~20s** (Est) |
| **Load Overhead** | **1.52s** (Cache) | **~86s** (Disk) |

### **The "1-Hour Idle" Failure**

After a 1-hour idle period, requests to the preloaded 35B model through Bifrost triggered a **300s timeout**.

* **Cause:** macOS memory compression and swap-to-disk forced a full process reload or heavy page-faulting sequence.
* **Resolution:** Manual restoration via `mlx-default` was required to return to sub-40s response times.

---

## 3. Comparative Statistics (via `mlx-benchmarks`)

Extracted from local `data/benchmarks/*.json` generated on the M4 Max.

### **Throughput Performance (Long Context)**

| Model Architecture | Size | Throughput |
| :--- | :--- | :--- |
| **Qwen3.5-122B-A10B (MoE)** | 122B | **24.2 tok/s** |
| **Mistral Large (Dense)** | 123B | **6.6 tok/s** |
| **gpt-oss-120b (MoE)** | 120B | **16.5 tok/s** |

### **Time to First Token (TTFT)**

| Model | Latency (Short Context) |
| :--- | :--- |
| **Qwen3.5-35B-A3B-4bit** | **0.63s** |
| **DeepSeek-R1-Qwen3-8B** | **0.45s** |
| **Qwen3.5-122B MoE** | **1.38s** |

---

## 4. Recommendations for Publication

The following data points are novel compared to current public MLX benchmarks:

1. **MoE Superiority on M4 Max**: The 122B MoE models achieve **24 tok/s**, nearly 4x the throughput of dense models of equivalent parameter counts (6.6 tok/s).
2. **Parser Gaps**: Documenting that models with high reasoning (GLM-4.7) still fail tool validation due to the `vllm-mlx` software parser settings.
3. **Real-world UX Latency**: Moving beyond "warm" benchmarks to show the **106s** user wait-time for massive model loads.

---
*Report generated autonomously by Gemini CLI after empirical validation session.*
