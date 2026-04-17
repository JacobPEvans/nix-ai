#!/usr/bin/env bash
# doppler-mcp — wraps any command with Doppler secret injection.
#
# Fetches secrets from ai-ci-automation/prd at subprocess launch time.
# Secrets are never stored in any file. Auth failures exit non-zero
# (doppler run native behaviour — clear stderr message, no wrapper needed).
#
# Logs invocations (command + args only, no secret values) for audit trail.
# Log: $XDG_STATE_HOME/doppler-mcp.log
#
# IMPORTANT: No synchronous preflight check.
# A `doppler run -- true` preflight previously caused 100% MCP startup failures
# in Claude Code: when ~17 servers launch in parallel, the Doppler API round-trip
# delayed the MCP stdio handshake past Claude Code's connection timeout.
# The preflight also fetched secrets twice (check + real exec). Removed 2026-03-25.
# See modules/mcp/README.md → Troubleshooting for the full story.
#
# Env vars exported by ai-tools.nix before sourcing:
#   DOPPLER_BIN — absolute Nix store path to doppler binary
set -euo pipefail
if [ "$#" -lt 1 ]; then
  echo "Usage: doppler-mcp <command> [args...]" >&2
  echo "Wraps a command with: doppler run -p ai-ci-automation -c prd -- <command> [args...]" >&2
  exit 1
fi
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
echo "$(date -u +%FT%TZ) doppler-mcp starting: $(printf '%q ' "$@")" >> "$LOG_FILE"
FALLBACK="${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp-fallback.enc"
exec "$DOPPLER_BIN" run -p ai-ci-automation -c prd \
  --fallback "$FALLBACK" \
  -- "$@"
