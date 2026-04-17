# pal-models-mlx.jq
#
# Transforms MLX vllm-mlx /v1/models JSON → PAL MCP custom_models.json format.
# Usage: curl -sf http://127.0.0.1:11434/v1/models | \
#          jq -L <dir> --slurpfile ratings <ratings.json> --from-file pal-models-mlx.jq
#
# Input format (OpenAI-compatible):
#   { "data": [{ "id": "mlx-community/<model-id>", ... }] }
#
# Output model_name uses Bifrost provider prefix: "mlx-local/mlx-community/<model-id>"
# Bifrost requires "provider/model" format; mlx-local routes to the local MLX backend.
#
# Filtering: model MUST have a real LMSYS arena Elo rating. Models without
# a benchmark score are omitted entirely. PAL only sees scored models.

include "pal-models-shared";

# Capability inferences from model name (no LMSYS field for these).
def has_vision: test("[Vv][Ll][Mm]|[Vv]ision|VL-");
def has_function_calling: test("Qwen3|Llama-4|Scout|Mistral|Nemotron");

{
  models: [
    .data[]
    | .id as $id
    | ($id | split("/") | last) as $short
    | ($short | ascii_downcase) as $lower
    | model_intelligence_score($id) as $score
    | select($score != null)               # require real benchmark score
    | {
        model_name: "mlx-local/\($id)",
        aliases: [$short, $lower],
        intelligence_score: $score,
        supports_json_mode: false,
        supports_function_calling: ($short | has_function_calling),
        supports_images: ($short | has_vision)
      }
  ]
}
