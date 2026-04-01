---
description: PAL MCP availability protocol — mandatory investigation before declaring unavailable
---

# PAL MCP Policy

PAL MCP routes prompts to external and local models (OpenAI, Gemini, OpenRouter, MLX).
It is the token offloading backbone. **Never declare it unavailable without investigation.**

## Configuration

- **DEFAULT_MODEL=auto**: PAL picks best model per-task based on available API keys
- **Providers**: OpenAI (o3, o4-mini, gpt-5, codex) → Gemini (pro, flash) → OpenRouter → MLX (local)
- **Secrets**: Injected via Doppler with encrypted fallback cache (no network dependency on start)

## Availability Check Protocol (MANDATORY)

Three-step escalation. All three steps MUST be followed before declaring unavailable.

### Step 1: ToolSearch

```text
ToolSearch("mcp__pal", max_results=5)
```

If tools found → PAL is loaded. Proceed.
If empty → **DO NOT STOP. Go to Step 2.** (deferred tools may not be populated yet)

### Step 2: Check server status

```bash
claude mcp list 2>/dev/null | grep "^pal:"
```

| Status | Action |
| ------ | ------ |
| `✓ Connected` | ToolSearch again: `select:mcp__pal__chat` |
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

- NEVER skip PAL based on ToolSearch alone
- NEVER declare "PAL unavailable" without completing all 3 steps
- NEVER silently omit PAL-dependent phases
- NEVER suggest manual workarounds without first attempting the protocol above

## Diagnostics

If PAL fails after the protocol:

1. `check-pal-mcp` — full health check (Doppler auth, secrets, MCP status)
2. `cat ~/.local/state/doppler-mcp.log` — recent invocation log
3. `doppler me` — verify Doppler authentication
