---
description: PAL MCP availability protocol — scoped to clink and consensus after Bifrost migration
---

# PAL MCP Policy

PAL MCP hosts two tools with no native Claude Code or Bifrost equivalent:
**`clink`** (parallel multi-model prompting) and **`consensus`** (multi-model
voting/agreement). Every other PAL tool has a native replacement — single-model
prompts go through the Bifrost AI gateway at `http://localhost:30080/v1`,
architecture/planning work goes through Plan mode or the `Plan` subagent, etc.
See the Phase 3 audit matrix on `JacobPEvans/nix-ai#450` for the full mapping.

This policy **only applies to `clink` and `consensus`**. Never declare either
unavailable without completing the investigation protocol below. Silently
skipping a multi-model step because `ToolSearch` came back empty is the
failure mode this rule exists to prevent.

## Configuration

- **DEFAULT_MODEL=auto**: PAL picks a model alias per-task; for single-model
  work this flows through `CUSTOM_API_URL` → Bifrost → the right provider.
  `clink`/`consensus` use their own multi-provider fan-out, not Bifrost.
- **Secrets**: Local PAL subprocess secrets (API keys, config) are injected by
  the `doppler-mcp` wrapper at launch time. This is separate from the Doppler
  **K8s Operator** that syncs Bifrost's in-cluster provider keys — different
  layer, don't conflate.
- **Bifrost is not a replacement** for `clink`/`consensus` — Bifrost is a
  single-request router, not a parallel orchestrator.

## Availability Check Protocol (MANDATORY for clink/consensus)

Three-step escalation. All three steps MUST be followed before declaring
`clink` or `consensus` unavailable.

### Step 1: ToolSearch

```text
ToolSearch("mcp__pal", max_results=5)
```

If `mcp__pal__clink` or `mcp__pal__consensus` appears → proceed.
If empty → **DO NOT STOP. Go to Step 2.** (deferred tools may not be populated yet)

### Step 2: Check server status

```bash
claude mcp list 2>/dev/null | grep "^pal:"
```

| Status | Action |
| ------ | ------ |
| `✓ Connected` | ToolSearch again: `select:mcp__pal__clink` |
| `✗ Failed` | Go to Step 3 |
| Not listed | Tell user: "PAL not registered. Run `check-pal-mcp` to diagnose." |

### Step 3: Attempt reconnection

```bash
claude mcp remove pal -s user && claude mcp add pal -s user -- doppler-mcp pal-mcp-server
```

Wait 5s, re-check with `claude mcp list`.
**CRITICAL**: Mid-session reconnected tools are invisible to ToolSearch.
Tell user: "PAL reconnected but requires session restart to load tools."

## NEVER-Do List

- NEVER skip `clink`/`consensus` based on ToolSearch alone
- NEVER declare either unavailable without completing all 3 steps
- NEVER silently omit a multi-model phase because PAL looked absent
- NEVER substitute Bifrost for `clink`/`consensus` — Bifrost cannot fan out
  to multiple models in one request
- NEVER suggest manual workarounds (e.g., sequential `chat` calls imitating
  `consensus`) without first attempting the protocol above

## Diagnostics

If PAL fails after the protocol:

1. `check-pal-mcp` — full health check (Doppler auth, secrets, MCP status)
2. `cat ~/.local/state/doppler-mcp.log` — recent invocation log
3. `doppler me` — verify Doppler authentication

## See also

- **Bifrost health**: `curl http://localhost:30080/health`
- **Bifrost model catalog**: `curl http://localhost:30080/v1/models`
- **Bifrost MCP registration**: `bifrost` block in `modules/mcp/default.nix`
- **Phase 3 audit matrix** (full PAL → native mapping):
  [JacobPEvans/nix-ai#450](https://github.com/JacobPEvans/nix-ai/issues/450)
