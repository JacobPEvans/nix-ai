# pal-models-mlx.jq
#
# Transforms MLX vllm-mlx /v1/models JSON → PAL MCP custom_models.json format.
# Usage: curl -sf http://127.0.0.1:11436/v1/models | jq --from-file pal-models-mlx.jq
#
# Input format (OpenAI-compatible):
#   { "data": [{ "id": "mlx-community/Qwen3.5-122B-A10B-4bit", ... }] }
#
# Output format (PAL custom_models.json):
#   { "models": [{ "model_name": "...", "aliases": [...], ... }] }

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
        function_calling: false,
        images: false
      }
  ]
}
