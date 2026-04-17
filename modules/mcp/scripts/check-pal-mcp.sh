#!/usr/bin/env bash
# check-pal-mcp — interactive PAL MCP health diagnostic.
#
# Run after darwin-rebuild switch or when PAL is absent from Claude Code sessions.
# Unlike check-pal-health.sh (non-blocking activation check that always exits 0),
# this script exits non-zero when critical failures are found.
set -euo pipefail
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp.log"

echo "=== PAL MCP Health Check ==="

echo ""
echo "1. Doppler version:"
"${DOPPLER_BIN:-doppler}" --version

echo ""
echo "2. Doppler auth status:"
"${DOPPLER_BIN:-doppler}" me 2>&1 || {
  echo "   ERROR: Not authenticated. Run: doppler login"
  exit 1
}

echo ""
echo "3. PAL secrets (ai-ci-automation/prd):"
# With DEFAULT_MODEL=auto, PAL works with ANY available provider.
# Warn about missing keys but only fail if NONE are available.
provider_secrets=(GEMINI_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY)
available=0
for secret in "${provider_secrets[@]}"; do
  if "${DOPPLER_BIN:-doppler}" secrets get "$secret" \
       --project ai-ci-automation \
       --config prd \
       --plain >/dev/null 2>&1; then
    echo "   OK: $secret available"
    available=$((available + 1))
  else
    echo "   WARN: $secret missing (PAL auto mode will use other providers)"
  fi
done
if [ "$available" -eq 0 ]; then
  echo "   ERROR: No provider API keys found. PAL MCP will not work."
  exit 1
fi
echo "   $available/${#provider_secrets[@]} providers available"

echo ""
echo "4. Last doppler-mcp log entries (if any):"
# Log has chmod 600 — diagnostic only, no secret values recorded
if [ -f "$LOG_FILE" ]; then
  tail -20 "$LOG_FILE"
else
  echo "   No log file found at $LOG_FILE (no failures recorded)"
fi

echo ""
echo "5. Claude Code MCP connection status:"
if command -v claude &>/dev/null; then
  pal_status=$(claude mcp list 2>/dev/null | grep "^pal:" || true)
  if [ -n "$pal_status" ]; then
    echo "   $pal_status"
  else
    echo "   PAL not found in Claude Code MCP server list"
    echo "   Register: claude mcp add pal -s user -- pal-mcp"
  fi
else
  echo "   claude CLI not in PATH — skipping"
fi

echo ""
echo "=== Health check complete ==="
