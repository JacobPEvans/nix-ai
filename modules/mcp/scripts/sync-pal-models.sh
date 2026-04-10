# sync-pal-models.sh
#
# Shared logic for PAL custom_models.json generation.
# Used by both sync-mlx-models CLI tool and home.activation.palCustomModels.
#
# Required environment variables (set by caller):
#   CURL         — path to curl binary
#   JQ           — path to jq binary
#   SCRIPTS_DIR  — directory holding pal-models-shared.jq (for jq -L)
#   MLX_JQ_FILE  — path to pal-models-mlx.jq
#   MLX_URL      — MLX /v1/models endpoint
#   OUTPUT_DIR   — directory for output file (also where lmarena-ratings.json lives)
#   OUTPUT_FILE  — full path to custom_models.json

mkdir -p "$OUTPUT_DIR"

# Refresh LMSYS arena ratings (sole source of intelligence scoring) before
# the MLX transform runs. Sourced because exec'ing would lose env vars.
# shellcheck source=./sync-lmarena-ratings.sh
. "${SCRIPTS_DIR}/sync-lmarena-ratings.sh"

# Query MLX vllm-mlx for loaded models (OpenAI format)
mlx_json=$("$CURL" -sf --connect-timeout 3 --max-time 5 "$MLX_URL" \
  | "$JQ" -L "$SCRIPTS_DIR" --slurpfile ratings "$RATINGS_FILE" --from-file "$MLX_JQ_FILE" \
  || echo '{"models": []}')

# Only overwrite if models were found (preserve previous file otherwise)
model_count=$(echo "$mlx_json" | "$JQ" '.models | length')
if [ "$model_count" -gt 0 ] || [ ! -f "$OUTPUT_FILE" ]; then
  echo "$mlx_json" > "$OUTPUT_FILE"
fi
