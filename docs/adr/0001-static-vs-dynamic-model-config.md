# ADR 0001: Static vs Dynamic Model Config Files for PAL MCP

**Status**: Accepted
**Date**: 2026-04-18
**Context**: PR #575 fix for PAL MCP showing `llama3.2` instead of real MLX models

## Documents in This Directory

_This ADR is part of [`docs/adr/`](README.md)._

## Context

PAL MCP needs to know which models are available, their capabilities, and intelligence
scores so it can route `chat`, `clink`, and `consensus` calls to the right backend.

Two approaches exist:

1. **Static enriched file** (`~/.config/pal-mcp/custom_models.json`) generated from
   live API + external LMSYS ratings data. File written at `darwin-rebuild switch`
   and refreshable via `sync-mlx-models` CLI.

2. **Dynamic API query** — PAL queries `http://127.0.0.1:11434/v1/models` directly
   at startup (the same way Open WebUI does).

The PAL `llama3.2` bug demonstrated that static files introduce a failure mode:
if the file is not deployed (wrong command in `~/.claude.json`), stale (wrong field
names), or missing (network down during activation), PAL falls through to its bundled
`conf/custom_models.json` which contains only `llama3.2`.

The question: **should the static file be eliminated in favor of a live API query?**

## Decision

**Keep the static enriched file.** PAL MCP queries `custom_models.json` at startup;
`sync-pal-models.sh` regenerates it from the live MLX API and LMSYS ratings at
activation time and on-demand via CLI.

**Rationale — what the raw `/v1/models` API does not provide:**

| Field | Available from `/v1/models`? | Source in the static file |
|-------|------------------------------|--------------------------|
| `model_name` with Bifrost prefix | No — raw API returns bare IDs | jq adds `mlx-local/` prefix |
| `intelligence_score` | No | LMSYS Elo ratings file |
| `supports_function_calling` | No | Name pattern match in jq |
| `supports_images` | No | Name pattern match in jq |
| `aliases` | No | Derived by jq from short name |

The jq enrichment transform (`pal-models-mlx.jq`) is not boilerplate — it adds
all the metadata that makes PAL's model selection useful. Moving this logic into PAL's
startup code would require forking PAL or submitting upstream changes.

**Alternatives rejected:**

| Alternative | Reason rejected |
|-------------|----------------|
| PAL queries `/v1/models` directly | Loses all enrichment (scores, capability flags, Bifrost routing prefix) |
| Bake model IDs into Nix options | Cannot enumerate all models at Nix eval time; models are downloaded at runtime |
| PAL has built-in LMSYS lookup | Couples PAL's startup to an external HTTP call; increases cold-start latency |
| Static file from Nix eval only | Nix evaluation cannot query the live `/v1/models` endpoint (pure, no I/O) |

## Consequences

**Positive:**

- Rich metadata enables intelligent model selection (`intelligence_score` drives routing)
- Works offline after initial generation (cached file survives network outages)
- Capability flags allow PAL to avoid models that do not support function calling

**Negative:**

- File can go stale after `mlx-switch` (requires `sync-mlx-models` + Claude restart)
- Field names must exactly match PAL's `providers/registries/base.py` expectations
  (was the root cause of PR #575: `json_mode` vs `supports_json_mode`)
- Deployment failures are silent — PAL falls through to bundled `llama3.2` without error

**Mitigations:**

- `sync-mlx-models` CLI for inter-rebuild refresh
- Activation-time generation ensures file is always current after `darwin-rebuild switch`
- Preserves previous file rather than writing empty list if MLX is unreachable

**Open risk**: A future PAL version bump (Renovate) could rename the expected fields
again. No automated smoke test validates PAL startup against `custom_models.json` today.
