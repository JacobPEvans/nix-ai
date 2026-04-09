# sync-pal-cloud-models.sh
#
# Dynamic cloud model discovery for PAL MCP via OpenRouter public API.
# Generates gemini_models.json, openai_models.json, openrouter_models.json
# from a single API call (no auth required).
#
# Same pattern as sync-pal-models.sh (MLX), extended to cloud providers.
#
# Required environment variables (set by caller):
#   CURL              — path to curl binary
#   JQ                — path to jq binary
#   GEMINI_JQ_FILE    — path to pal-models-gemini.jq
#   OPENAI_JQ_FILE    — path to pal-models-openai.jq
#   OPENROUTER_JQ_FILE — path to pal-models-openrouter.jq
#   OUTPUT_DIR        — directory for output files

OPENROUTER_API="https://openrouter.ai/api/v1/models"

mkdir -p "$OUTPUT_DIR"

# Single API call — reuse response for all 3 provider transforms
api_json=$("$CURL" -sf --connect-timeout 10 --max-time 30 "$OPENROUTER_API" || echo "")

if [ -z "$api_json" ]; then
  echo "  WARN: OpenRouter API unreachable — preserving previous model configs" >&2
  exit 0
fi

# Transform and write each provider config.
# Only overwrite if the transform produces models (preserves previous on jq errors).
_sync_provider() {
  _provider_name="$1"
  _jq_file="$2"
  _output_file="${OUTPUT_DIR}/${_provider_name}_models.json"

  _provider_json=$(echo "$api_json" | "$JQ" --from-file "$_jq_file" || echo '{"models": []}')
  _model_count=$(echo "$_provider_json" | "$JQ" '.models | length' || echo "0")

  if [ "$_model_count" -gt 0 ] || [ ! -f "$_output_file" ]; then
    echo "$_provider_json" > "$_output_file"
    echo "  ${_provider_name}: ${_model_count} models"
  else
    echo "  ${_provider_name}: 0 models (preserved previous)" >&2
  fi
}

_sync_provider "gemini" "$GEMINI_JQ_FILE"
_sync_provider "openai" "$OPENAI_JQ_FILE"
_sync_provider "openrouter" "$OPENROUTER_JQ_FILE"
