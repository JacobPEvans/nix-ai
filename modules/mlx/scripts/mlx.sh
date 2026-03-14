#!/usr/bin/env bash
# One-shot prompt against the local MLX inference server.
# Usage: mlx "What is the capital of France?"
# For streaming, interactive chat, or stdin piping, use mlx-chat instead.

prompt="${*:?Usage: mlx \"your prompt\"}"

curl -sf "${MLX_API_URL:?MLX_API_URL not set}/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg m "${MLX_DEFAULT_MODEL:?MLX_DEFAULT_MODEL not set}" \
    --arg p "$prompt" \
    '{model: $m, messages: [{role: "user", content: $p}]}')" \
| jq -r '.choices[0].message.content'
