# pal-models-openrouter.jq
#
# Transforms OpenRouter /api/v1/models → PAL openrouter_models.json format.
# Single source of truth for ALL cloud models, regardless of native provider.
#
# Filtering:
#   - created in last 90 days AND not deprecated
#   - MUST have a real LMSYS arena Elo rating (no heuristic fallback)
#
# Models without an LMSYS rating are omitted entirely. PAL only sees
# models with a real benchmark score.

include "pal-models-shared";

{
  models: [
    .data[]
    | select(.created > (now - 7776000))   # last 90 days
    | select(.expiration_date == null)     # not deprecated
    | model_intelligence_score(.id) as $score
    | select($score != null)               # require real benchmark score
    | {
        model_name: .id,
        aliases: [.id | split("/") | last],
        context_window: (.context_length // 8192),
        max_output_tokens: (.top_provider.max_completion_tokens // 8192),
        supports_function_calling: ((.supported_parameters // []) | index("tools") != null),
        supports_extended_thinking: ((.supported_parameters // []) | index("include_reasoning") != null),
        supports_json_mode: ((.supported_parameters // []) | index("structured_outputs") != null),
        supports_images: ((.architecture.modality // "") | test("image")),
        intelligence_score: $score
      }
  ]
}
