# pal-models-openai.jq
#
# Transforms OpenRouter /api/v1/models → PAL openai_models.json format.
# Filters to current OpenAI models only (GPT-5+, o4+), strips openai/ prefix.
# Usage: curl -sf https://openrouter.ai/api/v1/models | jq --from-file pal-models-openai.jq
#
# Version filter: gpt-[5-9] and o[4-9] ensures only current major versions.
# When gpt-6 or o5 ships, it passes automatically — no jq changes needed.
#
# Intelligence scoring uses family heuristics:
#   pro → 19, codex → 18, standard → 16, mini → 12, nano → 8, chat → 10

# Helper: strip provider prefix for native OpenAI API model names
def strip_prefix: sub("^openai/"; "");

# Helper: derive intelligence score from model family
def family_score:
  if test("pro") then 19
  elif test("codex") then 18
  elif test("mini") then 12
  elif test("nano") then 8
  elif test("chat") then 10
  else 16
  end;

# Helper: generate short aliases from model name
def make_aliases:
  strip_prefix as $bare |
  [$bare] +
  ([$bare | gsub("-"; "")] as $compact |
   if $compact != $bare then [$compact] else [] end);

{
  models: [
    .data[]
    | select(.id | test("^openai/(gpt-[5-9]|o[4-9])"))
    | select(.id | test("image|deep-research") | not)  # exclude image-gen and research variants
    | (.id | family_score) as $score
    | any(.supported_parameters[]?; . == "include_reasoning") as $has_reasoning
    | {
        model_name: (.id | strip_prefix),
        friendly_name: .name,
        aliases: (.id | make_aliases),
        intelligence_score: $score,
        description: .description,
        context_window: .context_length,
        max_output_tokens: (.top_provider.max_completion_tokens // 128000),
        supports_extended_thinking: $has_reasoning,
        supports_system_prompts: true,
        supports_streaming: true,
        supports_function_calling: any(.supported_parameters[]?; . == "tools"),
        supports_json_mode: any(.supported_parameters[]?; . == "structured_outputs"),
        supports_images: (.architecture.modality // "" | test("image")),
        supports_temperature: any(.supported_parameters[]?; . == "temperature"),
        use_openai_response_api: $has_reasoning,
        allow_code_generation: ($score >= 12)
      }
  ]
}
