#!/usr/bin/env bash
# Switch the active MLX model via llama-swap proxy.
# Usage: mlx-switch <model-id>

model="${1:?Usage: mlx-switch <model>}"

mlx-preflight "$model" || exit 1

echo "Switching to $model (this may take 20-60s for large models)..."

# Trigger the swap by sending a minimal request with the target model.
# llama-swap stops the current backend and starts the new one.
if ! curl -sf "${MLX_API_URL:?}/chat/completions" \
  -H "Content-Type: application/json" \
  --max-time 300 \
  -d "$(jq -n --arg m "$model" '{model: $m, messages: [{role: "user", content: "ping"}], max_tokens: 1}')" \
  > /dev/null 2>&1; then
  echo "Switch failed. Check: mlx-status" >&2
  exit 1
fi

echo "Model $model is now active."
