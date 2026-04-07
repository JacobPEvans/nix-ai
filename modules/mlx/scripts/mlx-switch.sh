#!/usr/bin/env bash
# Switch the active MLX model via llama-swap proxy.
# Auto-discovers and registers unregistered models before switching.
# Usage: mlx-switch mlx-community/Qwen3-235B-A22B-4bit

model="${1:?Usage: mlx-switch <model>}"

mlx-preflight "$model" || exit 1

# Check if model is registered in llama-swap config; auto-discover if not
config_path="${MLX_LLAMA_SWAP_CONFIG:-}"
if [ -n "$config_path" ] && [ -f "$config_path" ]; then
  if ! jq -e --arg m "$model" '.models[$m]' "$config_path" > /dev/null 2>&1; then
    echo "Model not in llama-swap config — running mlx-discover..."
    mlx-discover --quiet
    # Verify it was registered
    if ! jq -e --arg m "$model" '.models[$m]' "$config_path" > /dev/null 2>&1; then
      echo "ERROR: Model $model could not be auto-registered." >&2
      echo "Is it downloaded? Check: mlx-models" >&2
      exit 1
    fi
    echo "Model registered. Proceeding with switch."
  fi
fi

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
