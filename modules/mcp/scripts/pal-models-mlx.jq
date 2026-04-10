# pal-models-mlx.jq
#
# Transforms MLX vllm-mlx /v1/models JSON → PAL MCP custom_models.json format.
# Usage: curl -sf http://127.0.0.1:11434/v1/models | \
#          jq -L <dir> --slurpfile ratings <ratings.json> --from-file pal-models-mlx.jq
#
# Input format (OpenAI-compatible):
#   { "data": [{ "id": "mlx-community/<model-id>", ... }] }
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
    | ($short | ascii_downcase | gsub("-[0-9]+bit$"; "")) as $clean
    | model_intelligence_score($id) as $score
    | select($score != null)               # require real benchmark score
    | {
        model_name: $id,
        aliases: [$short, $clean],
        intelligence_score: $score,
        json_mode: false,
        function_calling: ($short | has_function_calling),
        images: ($short | has_vision)
      }
  ]
}
