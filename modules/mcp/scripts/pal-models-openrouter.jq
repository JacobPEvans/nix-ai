# pal-models-openrouter.jq
#
# Transforms OpenRouter /api/v1/models → PAL openrouter_models.json format.
# Keeps provider prefixes (OpenRouter format). Selects top models across providers.
# Usage: curl -sf https://openrouter.ai/api/v1/models | jq --from-file pal-models-openrouter.jq
#
# Provider filters (version-aware, future-proof):
#   google/gemini-[3-9]*    — current Gemini
#   openai/(gpt-[5-9]|o[4-9])*  — current OpenAI
#   anthropic/claude-(opus|sonnet)-[4-9]* — current Anthropic
#   x-ai/grok-[4-9]*       — current Grok
#   deepseek/*              — all DeepSeek (few models, all relevant)
#
# Intelligence scoring uses family heuristics across all providers.

# Helper: derive intelligence score from model family
def family_score:
  if test("opus") then 19
  elif test("pro|codex") then 18
  elif test("sonnet|grok-[4-9]") then 15
  elif test("flash-lite|lite|nano") then 8
  elif test("flash|mini|chat") then 12
  elif test("deepseek-r1") then 17
  else 14
  end;

# Helper: short alias from full OpenRouter ID
def make_aliases:
  [
    (. | split("/") | last),
    (. | split("/") | last | gsub("-preview$"; ""))
  ] | unique;

{
  models: [
    .data[]
    | select(
        (.id | test("^google/gemini-[3-9]")) or
        (.id | test("^openai/(gpt-[5-9]|o[4-9])")) or
        (.id | test("^anthropic/claude-(opus|sonnet)-[4-9]")) or
        (.id | test("^x-ai/grok-[4-9]")) or
        (.id | test("^deepseek/deepseek-(r1|v3)"))
      )
    | select(.id | test("image|deep-research|extended") | not)  # exclude niche variants
    | {
        model_name: .id,
        friendly_name: .name,
        aliases: (.id | make_aliases),
        intelligence_score: (.id | family_score),
        description: .description,
        context_window: .context_length,
        max_output_tokens: (.top_provider.max_completion_tokens // 65536),
        supports_extended_thinking: ([.supported_parameters[]? | select(. == "include_reasoning")] | length > 0),
        supports_json_mode: ([.supported_parameters[]? | select(. == "structured_outputs")] | length > 0),
        supports_function_calling: ([.supported_parameters[]? | select(. == "tools")] | length > 0),
        supports_images: (.architecture.modality // "" | test("image")),
        supports_temperature: ([.supported_parameters[]? | select(. == "temperature")] | length > 0),
        allow_code_generation: ((.id | family_score) >= 14)
      }
  ]
}
