# pal-models-gemini.jq
#
# Transforms OpenRouter /api/v1/models → PAL gemini_models.json format.
# Filters to current Gemini models only (version 3+), strips google/ prefix.
# Usage: curl -sf https://openrouter.ai/api/v1/models | jq --from-file pal-models-gemini.jq
#
# Version filter: gemini-[3-9] ensures only current major versions.
# When gemini-4 ships, it passes automatically — no jq changes needed.
#
# Intelligence scoring uses family heuristics, not per-model assignment:
#   pro → 18, flash → 12, flash-lite/lite → 8, image-gen → 10

# Helper: strip provider prefix for native Gemini API model names
def strip_prefix: sub("^google/"; "");

# Helper: derive intelligence score from model family
def family_score:
  if test("pro") then 18
  elif test("flash-lite|lite") then 8
  elif test("flash") then 12
  else 10
  end;

# Helper: generate short aliases from model name
def make_aliases:
  strip_prefix as $bare |
  [$bare] +
  ([$bare | gsub("-preview$"; "")] | if .[0] != $bare then . else [] end);

{
  models: [
    .data[]
    | select(.id | test("^google/gemini-[3-9]"))
    | select(.id | test("image-preview$") | not)  # exclude image-gen variants
    | (.id | family_score) as $score
    | {
        model_name: (.id | strip_prefix),
        friendly_name: .name,
        aliases: (.id | make_aliases),
        intelligence_score: $score,
        description: .description,
        context_window: .context_length,
        max_output_tokens: (.top_provider.max_completion_tokens // 65536),
        supports_extended_thinking: ([.supported_parameters[]? | select(. == "include_reasoning")] | length > 0),
        supports_system_prompts: true,
        supports_streaming: true,
        supports_function_calling: ([.supported_parameters[]? | select(. == "tools")] | length > 0),
        supports_json_mode: ([.supported_parameters[]? | select(. == "structured_outputs")] | length > 0),
        supports_images: (.architecture.modality // "" | test("image")),
        supports_temperature: ([.supported_parameters[]? | select(. == "temperature")] | length > 0),
        allow_code_generation: ($score >= 12)
      }
  ]
}
