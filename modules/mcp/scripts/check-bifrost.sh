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
# See: ~/git/orbstack-kubernetes for the cluster configuration.

set -euo pipefail

echo "=== Bifrost AI Gateway Health Check ==="

echo ""
echo "1. OrbStack K8s context reachability:"
if kubectl --context orbstack get nodes >/dev/null 2>&1; then
  echo "   OK: orbstack context reachable"
else
  echo "   ERROR: orbstack context not reachable (is OrbStack k8s running?)"
  exit 1
fi

echo ""
echo "2. Bifrost pod status (monitoring namespace):"
kubectl --context orbstack -n monitoring \
  get pods -l app=bifrost --no-headers 2>/dev/null \
  | awk '{print "   " $1 ": " $3 " (" $2 " ready)"}' \
  || echo "   WARN: No bifrost pods found"

echo ""
echo "3. Bifrost /health endpoint (NodePort :30080):"
if curl -sf --connect-timeout 5 http://localhost:30080/health 2>/dev/null; then
  echo ""
  echo "   OK"
else
  echo "   UNREACHABLE — pod may not be Ready"
fi

echo ""
echo "4. Bifrost /v1/models response:"
models_response=$(curl -s --connect-timeout 5 \
  http://localhost:30080/v1/models 2>/dev/null || echo "")
if [ -n "$models_response" ]; then
  if echo "$models_response" | jq -e '.data' >/dev/null 2>&1; then
    model_count=$(echo "$models_response" | jq '.data | length' 2>/dev/null || echo "0")
    echo "   OK: $model_count models available"
  elif echo "$models_response" | jq -e '.error' >/dev/null 2>&1; then
    err=$(echo "$models_response" | jq -r '.error.message' 2>/dev/null)
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
     get dopplersecret bifrost-provider-keys >/dev/null 2>&1; then
  sync_status=$(kubectl --context orbstack -n doppler-operator-system \
    get dopplersecret bifrost-provider-keys \
    -o jsonpath='{.status.conditions[?(@.type=="secrets.doppler.com/SecretSyncReady")].status}' 2>/dev/null \
    || echo "Unknown")
  echo "   bifrost-provider-keys sync status: $sync_status"
else
  echo "   WARN: DopplerSecret not found (operator not bootstrapped)"
  echo "   Bootstrap: kubectl apply -f https://github.com/DopplerHQ/kubernetes-operator/releases/latest/download/recommended.yaml"
fi

echo ""
echo "6. Claude Code MCP connection status:"
if command -v claude >/dev/null 2>&1; then
  bifrost_status=$(claude mcp list 2>/dev/null | grep "^bifrost:" || true)
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
