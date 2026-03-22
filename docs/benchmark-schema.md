# Benchmark Result Schema

Each benchmark run writes a JSON file to `data/benchmarks/` conforming to this schema
(formally defined in `data/benchmarks/schema.json`, JSON Schema draft-07).

## Filename Convention

```text
data/benchmarks/{YYYY-MM-DDTHHMMSSZ}-{git-sha7}-{suite}.json
```

Example: `data/benchmarks/2026-03-22T014523Z-0b1e958-framework-eval.json`

## Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | `"1"` | Yes | Always `"1"`. Bump for breaking changes. |
| `timestamp` | string (RFC 3339) | Yes | UTC run-start time (e.g. `2026-03-22T01:45:23Z`) |
| `git_sha` | string (≥7 chars) | Yes | Repo commit SHA at run time |
| `trigger` | `schedule` \| `pr` \| `workflow_dispatch` | Yes | What triggered the run |
| `pr_number` | integer \| null | No | PR number if trigger is `pr` |
| `suite` | string (enum) | Yes | Which benchmark suite ran (see suites table) |
| `model` | string | Yes | Model name used for inference |
| `skipped` | boolean | No | `true` when suite skipped (e.g. no MLX hardware) |
| `system` | object | Yes | System info at run time |
| `results` | array | Yes | Individual metric results |
| `memory_snapshots` | array | No | Memory measurements at run phases |
| `errors` | array of strings | No | Non-fatal errors or warnings |

## Suites

| Suite | Description | Requires MLX hardware |
|-------|-------------|----------------------|
| `throughput` | Token generation speed sweep across output lengths | Yes |
| `ttft` | Time to first token, cold vs warm | Yes |
| `tool-calling` | Tool selection accuracy and latency | Yes |
| `code-accuracy` | Code planning, review, and implementation via tool calls | Yes |
| `framework-eval` | LangGraph / Qwen-Agent / smolagents / Google ADK comparison | Yes |
| `capability-comparison` | Full capability suite vs Claude Opus 4.6 baselines (8 dimensions) | Yes |

## `system` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `os` | string | Yes | OS and version (e.g. `macOS 15.3.2`) |
| `chip` | string | Yes | CPU model (e.g. `Apple M4 Max`) |
| `memory_gb` | integer | Yes | Total RAM in GB |
| `vllm_mlx_version` | string | No | vllm-mlx package version |
| `runner` | string | No | GitHub Actions runner label |

## `results` Items

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Test or measurement name |
| `metric` | string | Yes | Metric type (e.g. `latency`, `throughput`, `score`) |
| `value` | number | Yes | Numeric value |
| `unit` | string | Yes | Unit (e.g. `seconds`, `tok/s`, `ratio`) |
| `tags` | object | No | String key-value metadata (framework, tokens, etc.) |
| `raw` | any | No | Original unmodified tool output |

## `memory_snapshots` Items

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `phase` | string | Yes | Run phase (`before`, `loading`, `peak`, `after`) |
| `rss_gb` | number | Yes | Process RSS in GB |
| `free_gb` | number | No | Free system memory in GB |
| `wired_gb` | number | No | Wired (non-pageable) memory in GB |
| `swap_mb` | number | No | Swap usage in MB |

## Validation

```bash
uv run scripts/benchmarks/validate-schema.py data/benchmarks/schema.json
uv run scripts/benchmarks/validate-schema.py data/benchmarks/2026-03-22T*.json
```
