# shellcheck shell=bash
# sync-pal-models.sh
#
# Shared logic for PAL custom_models.json generation.
# Used by both sync-mlx-models CLI tool and home.activation.palCustomModels.
#
# Required environment variables (set by caller):
#   CURL         — path to curl binary
#   JQ           — path to jq binary
#   SCRIPTS_DIR  — directory holding pal-models-shared.jq and sync-lmarena-ratings.sh
#   MLX_JQ_FILE  — path to pal-models-mlx.jq
#   MLX_URL      — MLX /v1/models endpoint
#   OUTPUT_DIR   — directory for output file (also where lmarena-ratings.json lives)
#   OUTPUT_FILE  — full path to custom_models.json

mkdir -p "$OUTPUT_DIR"
RATINGS_FILE="${OUTPUT_DIR}/lmarena-ratings.json"

# Refresh LMSYS arena ratings (sole source of intelligence scoring).
# Runs as subprocess so trap/var leaks cannot pollute this script.
bash "${SCRIPTS_DIR}/sync-lmarena-ratings.sh" || echo "  WARN: ratings sync failed, using existing file if any" >&2

# If ratings file is missing (never fetched), skip the transform entirely
# so we don't persist an empty model list.
if [ ! -f "$RATINGS_FILE" ]; then
  echo "  WARN: ${RATINGS_FILE} missing — preserving previous ${OUTPUT_FILE}" >&2
  exit 0
fi

# Query MLX vllm-mlx for loaded models (OpenAI format)
mlx_json=$("$CURL" -sf --connect-timeout 3 --max-time 5 "$MLX_URL" \
  | "$JQ" -L "$SCRIPTS_DIR" --slurpfile ratings "$RATINGS_FILE" --from-file "$MLX_JQ_FILE" \
  || echo '{"models": []}')

# Only overwrite if models were found (preserve previous file otherwise)
model_count=$(echo "$mlx_json" | "$JQ" '.models | length')
if [ "$model_count" -gt 0 ] || [ ! -f "$OUTPUT_FILE" ]; then
  echo "$mlx_json" > "$OUTPUT_FILE"
fi
