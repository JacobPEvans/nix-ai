<!-- cspell:words TTFT hellaswag parameterize keyerror multimodal Hendrycks -->
<!-- cspell:words evalplus humaneval mbpp sympy minerva bigcode codegen toks -->
<!-- cspell:words setrlimit RLIMIT antlr unloadable vllm mlx -->
# MLX Benchmark History

Archived narratives for prior benchmark sessions. The current summary lives in
[`mlx-benchmarks.md`](mlx-benchmarks.md); auto-generated tables there always show
the latest 5 runs per suite. Entries here are kept as human-readable context for
configuration decisions and multi-model baselines.

## 2026-04-11 — Phase B sweep, multimodal incident, benchmark pivot

### The multimodal incident

On 2026-02-24, HuggingFace upstream silently republished
`mlx-community/Qwen3.5-35B-A3B-4bit` as a multimodal variant
(`Qwen3_5MoeForConditionalGeneration`, `pipeline_tag: image-text-to-text`,
sha `1e20fd8d42056f870933bf98ca6211024744f7ec`). The prior PR 465 default
pointed at this model. Any fresh Claude Code session on main after that date
raised a `TypeError: cannot unpack non-iterable NoneType object` from
`vllm-mlx` `load_model_with_fallback`. Swapping the default was mandatory
regardless of benchmark outcomes.

Detection happened during Phase B smoke testing when a fresh Claude Code
session could not load the default. HF API inspection via
`curl .../api/models/<id>` showed the drift. Follow-up issue 3
(HF pipeline_tag drift guard in `nix flake check`) was filed so this class
of bug is caught automatically on future darwin-rebuilds.

### Benchmark infrastructure: four blockers, one pivot

The Phase A infrastructure commits (61cda7f, 939535e, 2c59f0d from the
post-PR-465 work) wired up two new suites: `evalplus` (rigorous code gen via
HumanEval+ / MBPP+) and `math-hard` (structured reasoning via
Hendrycks MATH500 + leaderboard hard). Exercising them surfaced four
independent bugs:

1. **`max_length=2048` default** in lm-eval's `local-chat-completions`
   backend. Combined with `max_gen_toks=1024`, only ~1023 tokens remain for
   the prompt. Chat-wrapped HumanEval prompts blow through it and responses
   get truncated mid-word (observed: `"Tru"` instead of `"True"`, `"goa"`
   instead of `"goal"`). Fix: `max_length=32768` in the `mlx-eval` wrapper
   `model_args`.

2. **Completion-style tasks fail on chat models.** `humaneval_plus`,
   `mbpp_plus`, and `humaneval` are raw-continuation tasks that expect a base
   model to pick up from a function signature. Chat models wrap code in
   markdown blocks with narrative prose and score 0% — the extractors only
   prepend the signature to the prose prefix and lose the actual code. The
   `_instruct` variants (`humaneval_instruct`, `mbpp_plus_instruct`) have
   different extractors but the same fundamental issue with markdown code
   blocks.

3. **Standalone evalplus package RLIMIT on macOS.** `evalplus.codegen` works
   cleanly via the OpenAI backend against vllm-mlx (generations are perfect),
   but `evalplus.evaluate`'s `reliability_guard` calls
   `resource.setrlimit(RLIMIT_AS, ...)` which raises
   `ValueError: current limit exceeds maximum limit` on Darwin. Every sample
   errors during sandbox setup, every score is 0. `--i_just_wanna_run` does
   not bypass this.

4. **`lm-eval[math]` extras required** for `minerva_math*` tasks (sympy,
   math_verify, antlr4-python3-runtime).

### The pivot

Dropped the `evalplus` coding suite from this PR. The suite is stubbed with
an informative skip record (`collect-results.py::run_evalplus_suite`) so
`generate-summary.py` and schema validation keep working and the suite name
stays registered. Follow-up issues track proper coding benchmark paths:

- Issue 1: Docker-based EvalPlus scorer (bypass macOS RLIMIT_AS)
- Issue 6: Vendor `humaneval_plus_instruct` task YAML for lm-eval
- Issue 8: bigcode-evaluation-harness evaluation spike

`math-hard` simplified to `minerva_math500 @ 100` only. `leaderboard_math_hard`
was removed because it's a task group that multiplies `--limit` across 7
subtasks (560 samples total) and blows past the 30-min per-task timeout.
`minerva_math500` alone is a sufficient discriminator: Qwen3-Coder-30B scored
47% math_verify, not saturated.

### Sweep results (Phase B, 2026-04-11)

Hardware: M4 Max 128 GB. Configuration: `lm-eval[api,math]==0.4.11`,
`max_length=32768`, `num_concurrent=4`, `minerva_math500` @ 100 samples.
vllm-mlx 0.2.6.

Results table will be populated by `analyze-and-draft-decision.sh` once the
full 11-model sweep completes.

### Default swap rationale

Swapping from the broken multimodal variant to
`mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit`:

- Loads on vllm-mlx 0.2.6 (confirmed via smoke test)
- 21 GB RAM, well within the 108 GB budget
- Qwen3 MoE architecture family — same family as the prior default
- 47% math_verify on minerva_math500 baseline measurement
- Dedicated coder tuning — the Coder variant of Qwen3-30B-A3B Instruct,
  designed for software engineering tasks

If any candidate in the sweep beat this score by ≥ 3 pp, the default would
swap to the winner. Otherwise this is the rescue baseline.

### Takeaway

The `evalplus` + HumanEval family was designed in 2021 for GPT-3-style base
models. The 2023-2025 chat-instruct tuning revolution broke their implicit
output-format assumptions. For coding benchmarks on chat models, reach for
purpose-built harnesses (evalplus standalone, bigcode-evaluation-harness) —
not the decade-old lm-eval task definitions. Math benchmarks are more
forgiving because CoT prompting is the natural output format.

mlx-community is "best-effort community quants", not a stable artifact
repository. Capture `sha` in every benchmark result and verify `pipeline_tag`
via the HF API before trusting a cached checkpoint.

---

## 2026-03-22 — Full Suite with Tool Calling & Code Accuracy

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB,
`--enable-auto-tool-choice --tool-call-parser qwen` (PR #280).
System: macOS 26.3.1, vllm-mlx 0.2.6, PID 1438.

### Throughput Sweep (5 lengths)

| Test | Output | Elapsed | tok/s |
|------|--------|---------|-------|
| Short gen (50 tok) | 50 | 7.78s | 6.4 |
| Short gen (100 tok) | 100 | 5.22s | 19.2 |
| Medium gen (256 tok) | 256 | 9.88s | 25.9 |
| Long gen (512 tok) | 512 | 19.04s | 26.9 |
| Long gen (1024 tok) | 1024 | 39.47s | 25.9 |

Note: Lower tok/s than previous run (25-27 vs 44-49) because tool-calling mode
enables Qwen3's `<think>` reasoning tokens which count toward completion_tokens.
The model generates internal reasoning before responding, trading throughput for
quality. This is the expected behavior when `--tool-call-parser qwen` is active.

### TTFT (Cold vs Warm, 3 runs each)

| Test | Latency |
|------|---------|
| Cold avg (3 unique prompts) | 0.566s |
| Warm avg (3 cached prompts) | 0.652s |
| Cache speedup | 0.9x (no benefit) |

Prefix cache shows no benefit with tool-calling mode enabled. The `<think>` tokens
likely invalidate cache entries since the model's internal reasoning varies per request.

### Tool Calling (OpenAI-compatible function calling)

| Test | Latency | Tokens | Called Tool? | Details |
|------|---------|--------|-------------|---------|
| Weather query (should call) | 7.89s | 104 | YES | `get_weather({"location": "San Francisco"})` |
| Weather + unit (both args) | 6.32s | 131 | YES | `get_weather({"location": "Tokyo", "unit": "celsius"})` |
| No tool needed (math) | 4.95s | 84 | NO | Correctly answered without tool |
| Ambiguous (climate) | 9.03s | 200 | NO | Correctly reasoned climate != weather tool |

Tool calling accuracy: **4/4 correct decisions** (2 correct calls, 2 correct abstentions).

### Concurrent Requests (3 parallel)

| Requests | Total Tokens | Elapsed | Aggregate tok/s |
|----------|-------------|---------|-----------------|
| 3 | 600 | 23.71s | 25.3 |

No throughput scaling with concurrency — model is memory-bandwidth-bound. 25.3 aggregate
tok/s across 3 requests ≈ same as single-request throughput (25.9 tok/s).

### Code Accuracy with Tool Calling

#### Test 1: Code Planning (tool selection accuracy)

| Task | First Tool | Expected | Correct? |
|------|-----------|----------|----------|
| Add validation to auth.py | file_read | file_read | YES |
| Find functions without error handling | bash_exec | grep_search | NO (reasonable alt) |
| Create config.yaml | file_write | file_write | YES |
| Run test suite | bash_exec | bash_exec | YES |

Score: **3/4** (75%). The model chose `bash_exec find` instead of `grep_search` for
one case — a reasonable alternative approach.

#### Test 2: Code Implementation (bug fix via tool call)

| Bug | Tool Called | Correct Tool? | Valid Fix? |
|-----|-----------|---------------|-----------|
| Off-by-one error | file_read | NO | MAYBE |
| SQL injection | file_read | NO | MAYBE |

Score: **0/2** for direct `file_edit`. The model chose to `file_read` first before
editing — actually the safer approach (read-before-edit), but scored as incorrect
since the test expected direct `file_edit`. In a real agentic loop, step 2 would
be the edit. This matches Claude Code's own pattern of reading files before editing.

#### Test 3: Code Review (bug detection)

| Bugs Planted | Bugs Found | Accuracy |
|-------------|-----------|----------|
| 3 (off-by-one, null check, SQL injection) | 3 | **100%** |

All three planted bugs detected in 18.7s. No false positives.

#### Test 4: Multi-step Tool Chain

| Step | Tool | Expected | Correct? |
|------|------|----------|----------|
| 1 | grep_search | grep_search | YES |
| 2 | (summarized directly) | file_read | OK |

The model correctly searched with grep first, then summarized the results directly
instead of reading each file — an efficient optimization.

### Memory Timeline

| Time | Phase | vllm RSS (GB) | vllm Peak (GB) | Free (GB) | Active (GB) | Wired (GB) | Compressed (GB) | Swap |
|------|-------|---------------|----------------|-----------|-------------|------------|-----------------|------|
| 00:57:28 | idle (pre-test) | 65 | 65 | 2.1 | 40.6 | 5.6 | 37.3 | 0.00M |
| 00:58:50 | after throughput | 65 | 65 | 0.1 | 24.8 | 70.1 | 7.2 | 0.00M |
| 00:58:54 | after TTFT | 65 | 65 | 0.1 | 24.1 | 71.6 | 7.2 | 0.00M |
| 00:59:23 | after tool calling | 65 | 65 | 0.9 | 24.5 | 69.9 | 7.3 | 0.00M |
| 00:59:47 | after concurrent | 65 | 65 | 0.4 | 24.6 | 70.1 | 7.3 | 0.00M |
| 01:00:04 | idle (post-test) | 65 | 68 | 1.7 | 83.7 | 7.2 | 8.1 | 0.00M |

vllm-mlx peak RSS reached 68 GB briefly (3 GB above baseline) — first time peak
exceeded baseline. Likely caused by concurrent request KV cache allocation. Still
well within the 100 GB hard limit with zero swap.

### Key Takeaways

- **Tool calling works reliably**: 4/4 correct tool decisions, proper argument extraction
- **Code review is strong**: 3/3 bugs found with zero false positives
- **Read-before-edit pattern**: Model prefers to read files before editing — same as
  Claude Code's approach, and the right instinct for safety
- **Throughput trades for quality**: `<think>` reasoning tokens reduce raw tok/s from
  ~45 to ~26 but improve decision quality
- **Memory stable**: 65 GB baseline, 68 GB peak, zero swap throughout

## 2026-03-22 — Post-OOM Guardrails (PR #273 merged)

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB.
System: macOS 26.3.1, vllm-mlx 0.2.6.

| Test | Metric | Value | Notes |
|------|--------|-------|-------|
| Short gen (50 tok) | tok/s | 23.6 | Single request, warm server |
| Long gen (512 tok) | tok/s | 44.5 | Single request |
| TTFT cold | latency | 1.13s | Unique prompt, no prefix cache |
| TTFT warm | latency | 0.29s | Repeated prompt, prefix cache hit |
| Cache speedup | ratio | 3.9x | warm vs cold TTFT |

## 2026-03-22 — Memory-Tracked Throughput Sweep

Config: KV cache 16 GB, ProcessType=Background, HardResourceLimits 100 GB.
System: macOS 26.3.1, vllm-mlx 0.2.6, PID 1438.

Sequential generation tests with memory snapshots via `footprint` (process)
and `vm_stat` (system). All values in GB unless noted.

### Throughput

| Test | Tokens | Time | tok/s |
|------|--------|------|-------|
| Short gen | 50 | 1.95s | 25.6 |
| Medium gen | 256 | 5.39s | 47.5 |
| Long gen | 512 | 10.43s | 49.1 |
| Rapid fire 1/3 | 50 | 1.32s | 37.9 |
| Rapid fire 2/3 | 50 | 1.27s | 39.4 |
| Rapid fire 3/3 | 50 | 1.22s | 41.0 |

### Memory Timeline

| Time | Phase | vllm RSS (GB) | vllm Peak (GB) | Free (GB) | Active (GB) | Wired (GB) | Compressed (GB) | Swap |
|------|-------|---------------|----------------|-----------|-------------|------------|-----------------|------|
| 23:24:05 | idle (pre-test) | 65 | 65 | 0.9 | 58.9 | 5.7 | 2.7 | 0.00M |
| 23:24:07 | after short gen (50 tok) | 65 | 65 | 0.7 | 22.1 | 69.8 | 2.7 | 0.00M |
| 23:24:13 | after medium gen (256 tok) | 65 | 65 | 1.4 | 21.7 | 70.7 | 2.6 | 0.00M |
| 23:24:23 | after long gen (512 tok) | 65 | 65 | 1.7 | 22.5 | 70.6 | 2.6 | 0.00M |
| 23:24:28 | after 3x rapid short gen | 65 | 65 | 1.5 | 22.3 | 71.3 | 2.6 | 0.00M |
| 23:24:33 | idle (post-test, +5s) | 65 | 65 | 2.2 | 86.3 | 5.0 | 2.6 | 0.00M |

### Memory Observations

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

## 2026-03-20 — Initial Baseline (Issue #257)

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

- **Throughput stable** at ~44 tok/s — 16 GB KV cap has no impact (bandwidth-bound)
- **Short gen improved** 5.5 → 23.6 tok/s (warm server vs cold TTFT in baseline)
- **TTFT improved** cold 2.0s → 1.13s, warm 0.76s → 0.29s
- **OOM guardrails zero cost** — ProcessType=Background is metadata-only
