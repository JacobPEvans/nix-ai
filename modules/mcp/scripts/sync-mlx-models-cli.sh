#!/usr/bin/env bash
# sync-mlx-models-cli.sh
#
# CLI tool to refresh PAL custom_models.json from the live MLX endpoint.
# Normally the static Nix-generated config covers all configured models,
# but this is useful after downloading a new model without a rebuild.
#
# Queries the MLX vllm-mlx /v1/models endpoint and overwrites
# ~/.config/pal-mcp/custom_models.json with discovered models.
#
# Usage: sync-mlx-models

set -euo pipefail

MLX_URL="${MLX_URL:-http://127.0.0.1:11434/v1/models}"
OUTPUT_DIR="${HOME}/.config/pal-mcp"
OUTPUT_FILE="${OUTPUT_DIR}/custom_models.json"

mkdir -p "$OUTPUT_DIR"

# Query MLX for loaded models (OpenAI-compatible format)
mlx_response=$(curl -sf --connect-timeout 3 --max-time 5 "$MLX_URL" 2>/dev/null || echo '{}')

if [ "$mlx_response" = '{}' ]; then
  echo "MLX server not reachable at $MLX_URL — preserving existing config."
  exit 0
fi

# Transform to PAL custom_models.json format
mlx_json=$(echo "$mlx_response" | jq '
  {
    models: [
      .data[]
      | .id as $id
      | ($id | split("/") | last) as $short
      | ($short | ascii_downcase | gsub("-[0-9]+bit$"; "")) as $clean
      | {
          model_name: $id,
          aliases: [$short, $clean],
          intelligence_score: 17,
          speed_score: 12,
          json_mode: false,
          function_calling: true,
          images: false
        }
    ]
  }
' 2>/dev/null || echo '{"models": []}')

model_count=$(echo "$mlx_json" | jq '.models | length')

if [ "$model_count" -gt 0 ]; then
  echo "$mlx_json" > "$OUTPUT_FILE"
  echo "Updated $OUTPUT_FILE with $model_count model(s)."
else
  echo "No models found — preserving existing config."
fi

echo "Restart Claude Code to pick up changes."
