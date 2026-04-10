# pal-models-mlx.jq
#
# Transforms MLX vllm-mlx /v1/models JSON → PAL MCP custom_models.json format.
# Usage: curl -sf http://127.0.0.1:11434/v1/models | jq --from-file pal-models-mlx.jq
#
# Input format (OpenAI-compatible):
#   { "data": [{ "id": "mlx-community/<model-id>", ... }] }
#
# Output format (PAL custom_models.json):
#   { "models": [{ "model_name": "...", "aliases": [...], ... }] }
#
# Scoring: size-aware heuristics derived from model name patterns.
# Larger parameter counts → higher intelligence, lower speed.

# Helper: derive intelligence and speed scores from model size.
# Patterns use [-] prefix boundary to avoid substring false positives
# (e.g., "3B" matching "13B" or "235B"). Model names follow the convention
# {name}-{size}-{quant} so sizes always follow a hyphen.
def model_scores:
  if test("-235B|-230B") then { intelligence: 19, speed: 6 }
  elif test("-122B|-120B") then { intelligence: 18, speed: 8 }
  elif test("-70B|-72B|-78B") then { intelligence: 17, speed: 8 }
  elif test("-32B|-35B|-27B") then { intelligence: 15, speed: 12 }
  elif test("-17B|-14B|-16E") then { intelligence: 13, speed: 15 }
  elif test("-8B|-7B|-3B") then { intelligence: 10, speed: 18 }
  else { intelligence: 14, speed: 10 }
  end;

# Helper: detect vision capability from model name
def has_vision: test("[Vv][Ll][Mm]|[Vv]ision|VL-");

# Helper: detect function calling capability from model name
def has_function_calling: test("Qwen3|Llama-4|Scout|Mistral|Nemotron");

{
  models: [
    .data[]
    | .id as $id
    | ($id | split("/") | last) as $short
    | ($short | ascii_downcase | gsub("-[0-9]+bit$"; "")) as $clean
    | ($short | model_scores) as $scores
    | {
        model_name: $id,
        aliases: [$short, $clean],
        intelligence_score: $scores.intelligence,
        speed_score: $scores.speed,
        json_mode: false,
        function_calling: ($short | has_function_calling),
        images: ($short | has_vision)
      }
  ]
}
