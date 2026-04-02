#!/usr/bin/env bash
# Post-activation PAL MCP health check
#
# Runs after darwin-rebuild switch to surface PAL issues early.
# Non-blocking: always exits 0 (warnings only, never fails activation).
#
# Expected env vars (set by caller in pal-models.nix):
#   DOPPLER      — path to doppler binary
#   PAL_MCP_BIN  — path to pal-mcp-server binary (Nix store path)
#   PAL_LOG_DIR  — writable directory for PAL logs
#
# Intentionally omits -e: each check runs independently and failures are
# tallied in _fail rather than aborting the script.
set -uo pipefail

_pass=0
_fail=0

echo ""
echo "--- PAL MCP Health Check ---"

# 1. Verify pal-mcp-server binary exists (uses Nix store path, not PATH lookup)
if [ -x "${PAL_MCP_BIN:-}" ]; then
  echo "  PASS: pal-mcp-server binary found"
  _pass=$((_pass + 1))
else
  echo "  FAIL: pal-mcp-server binary not found or not executable"
  _fail=$((_fail + 1))
fi

# 2. Verify Doppler can authenticate
_doppler_authed=0
if "$DOPPLER" me >/dev/null 2>&1; then
  echo "  PASS: Doppler authenticated"
  _pass=$((_pass + 1))
  _doppler_authed=1
else
  echo "  WARN: Doppler not authenticated — run 'doppler login'"
  _fail=$((_fail + 1))
fi

# 3. Verify PAL secrets are accessible (only if Doppler authed)
if [ "$_doppler_authed" -eq 1 ]; then
  for secret in GEMINI_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY; do
    if "$DOPPLER" secrets get "$secret" \
         --project ai-ci-automation \
         --config prd \
         --plain >/dev/null 2>&1; then
      echo "  PASS: $secret accessible"
      _pass=$((_pass + 1))
    else
      echo "  WARN: $secret missing or unreadable in ai-ci-automation/prd"
      _fail=$((_fail + 1))
    fi
  done
fi

# 4. Verify PAL_LOG_DIR is writable
if [ -d "$PAL_LOG_DIR" ] && [ -w "$PAL_LOG_DIR" ]; then
  echo "  PASS: PAL_LOG_DIR writable ($PAL_LOG_DIR)"
  _pass=$((_pass + 1))
else
  echo "  WARN: PAL_LOG_DIR not writable ($PAL_LOG_DIR)"
  _fail=$((_fail + 1))
fi

# Summary
if [ "$_fail" -eq 0 ]; then
  echo "  Result: ALL PASSED ($_pass checks)"
else
  echo "  Result: $_fail issue(s), $_pass passed — PAL MCP may not work correctly"
  echo "  Fix: Run 'doppler login' then 'check-pal-mcp' to diagnose"
fi

echo "---"
echo ""

# Never block activation
exit 0
