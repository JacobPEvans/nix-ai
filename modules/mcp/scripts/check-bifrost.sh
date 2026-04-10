#!/usr/bin/env bash
# check-bifrost.sh — Health check for Bifrost AI gateway in OrbStack
#
# Verifies the Bifrost AI gateway running in the OrbStack monitoring stack:
#   1. OrbStack k8s context is reachable
#   2. Bifrost pod is Running and Ready
#   3. /health endpoint reachable via NodePort :30080
#   4. /v1/models endpoint responds (data on success, error on missing keys)
#   5. DopplerSecret status (sync from Doppler -> bifrost-provider-keys)
#   6. Claude Code MCP server registration
#
# Stderr from kubectl/curl/jq/claude is left visible — error output is the
# whole point of a health check, so we don't redirect it to /dev/null.
#
# See: ~/git/orbstack-kubernetes for the cluster configuration.

set -euo pipefail

echo "=== Bifrost AI Gateway Health Check ==="

echo ""
echo "1. OrbStack K8s context reachability:"
if kubectl --context orbstack get nodes >/dev/null; then
  echo "   OK: orbstack context reachable"
else
  echo "   ERROR: orbstack context not reachable (is OrbStack k8s running?)"
  exit 1
fi

echo ""
echo "2. Bifrost pod status (monitoring namespace):"
# kubectl exits 0 even when 0 pods match a label selector. Capture the output
# and explicitly check for emptiness instead of relying on pipe exit codes.
pods=$(kubectl --context orbstack -n monitoring \
  get pods -l app=bifrost --no-headers || true)
if [ -z "$pods" ]; then
  echo "   WARN: No bifrost pods found"
else
  echo "$pods" | gawk '{print "   " $1 ": " $3 " (" $2 " ready)"}'
fi

echo ""
echo "3. Bifrost /health endpoint (NodePort :30080):"
if curl -sf --connect-timeout 5 http://localhost:30080/health; then
  echo ""
  echo "   OK"
else
  echo "   UNREACHABLE — pod may not be Ready"
fi

echo ""
echo "4. Bifrost /v1/models response:"
models_response=$(curl -s --connect-timeout 5 \
  http://localhost:30080/v1/models || echo "")
if [ -n "$models_response" ]; then
  if echo "$models_response" | jq -e '.data' >/dev/null; then
    model_count=$(echo "$models_response" | jq '.data | length')
    echo "   OK: $model_count models available"
  elif echo "$models_response" | jq -e '.error' >/dev/null; then
    err=$(echo "$models_response" | jq -r '.error.message')
    echo "   WARN: $err"
    echo "   (expected when Doppler operator not bootstrapped)"
  else
    echo "   ERROR: unexpected response: $(echo "$models_response" | head -c 100)"
  fi
else
  echo "   UNREACHABLE"
fi

echo ""
echo "5. Doppler operator secret sync:"
if kubectl --context orbstack -n doppler-operator-system \
     get dopplersecret bifrost-provider-keys >/dev/null; then
  sync_status=$(kubectl --context orbstack -n doppler-operator-system \
    get dopplersecret bifrost-provider-keys \
    -o jsonpath='{.status.conditions[?(@.type=="secrets.doppler.com/SecretSyncReady")].status}' \
    || echo "Unknown")
  echo "   bifrost-provider-keys sync status: $sync_status"
else
  echo "   WARN: DopplerSecret not found (operator not bootstrapped)"
  echo "   Bootstrap: kubectl apply -f https://github.com/DopplerHQ/kubernetes-operator/releases/latest/download/recommended.yaml"
fi

echo ""
echo "6. Claude Code MCP connection status:"
if command -v claude >/dev/null; then
  bifrost_status=$(claude mcp list | grep "^bifrost:" || true)
  if [ -n "$bifrost_status" ]; then
    echo "   $bifrost_status"
  else
    echo "   bifrost not found in Claude Code MCP server list"
    echo "   Run: darwin-rebuild switch (to load updated nix-ai config)"
  fi
else
  echo "   claude CLI not in PATH — skipping"
fi

echo ""
echo "=== Health check complete ==="
