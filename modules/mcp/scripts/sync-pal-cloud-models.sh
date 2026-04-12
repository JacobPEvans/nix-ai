# shellcheck shell=bash
# sync-pal-cloud-models.sh
#
# Dynamic cloud model discovery for PAL MCP via OpenRouter public API.
# Generates openrouter_models.json from a single API call (no auth required).
#
# Required environment variables (set by caller):
#   CURL              — path to curl binary
#   JQ                — path to jq binary
#   SCRIPTS_DIR       — directory holding pal-models-shared.jq and sync-lmarena-ratings.sh
#   OPENROUTER_JQ_FILE — path to pal-models-openrouter.jq
#   OUTPUT_DIR        — directory for output files (also where lmarena-ratings.json lives)

OPENROUTER_API="https://openrouter.ai/api/v1/models"
OUTPUT_FILE="${OUTPUT_DIR}/openrouter_models.json"
RATINGS_FILE="${OUTPUT_DIR}/lmarena-ratings.json"

mkdir -p "$OUTPUT_DIR"

# Refresh LMSYS arena ratings (sole source of intelligence scoring).
# Runs as subprocess so trap/var leaks cannot pollute this script.
bash "${SCRIPTS_DIR}/sync-lmarena-ratings.sh" || echo "  WARN: ratings sync failed, using existing file if any" >&2

# If ratings file is missing, preserve the existing output — don't persist
# an empty model list just because the ratings fetch failed.
if [ ! -f "$RATINGS_FILE" ]; then
  echo "  WARN: ${RATINGS_FILE} missing — preserving previous ${OUTPUT_FILE}" >&2
  exit 0
fi

# Fetch and transform — preserves previous file on any failure
api_json=$("$CURL" -sf --connect-timeout 10 --max-time 30 "$OPENROUTER_API" || echo "")

if [ -z "$api_json" ]; then
  echo "  WARN: OpenRouter API unreachable — preserving previous model config" >&2
  exit 0
fi

provider_json=$(echo "$api_json" | "$JQ" -L "$SCRIPTS_DIR" --slurpfile ratings "$RATINGS_FILE" --from-file "$OPENROUTER_JQ_FILE" || echo '{"models": []}')
model_count=$(echo "$provider_json" | "$JQ" '.models | length' || echo "0")

if [ "$model_count" -gt 0 ] || [ ! -f "$OUTPUT_FILE" ]; then
  echo "$provider_json" > "$OUTPUT_FILE"
  echo "  openrouter: ${model_count} models"
else
  echo "  openrouter: 0 models (preserved previous)" >&2
fi
