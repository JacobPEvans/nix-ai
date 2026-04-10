# pal-models-openrouter.jq
#
# Transforms OpenRouter /api/v1/models → PAL openrouter_models.json format.
# Single source of truth for ALL cloud models, regardless of native provider.
#
# Filtering: created in last 90 days AND not deprecated.
#   - New models appear automatically when OpenRouter indexes them
#   - Old models age out automatically
#   - Deprecated models are excluded via expiration_date
#
# Scoring: derived from prompt token price.
#   Pricing tracks capability more reliably than name heuristics —
#   providers price flagship models higher than mid-tier and cheap variants.

{
  models: [
    .data[]
    | select(.created > (now - 7776000))   # last 90 days
    | select(.expiration_date == null)     # not deprecated
    | (.pricing.prompt | tonumber) as $p
    | {
        model_name: .id,
        aliases: [.id | split("/") | last],
        context_window: (.context_length // 8192),
        max_output_tokens: (.top_provider.max_completion_tokens // 8192),
        supports_function_calling: ((.supported_parameters // []) | index("tools") != null),
        supports_extended_thinking: ((.supported_parameters // []) | index("include_reasoning") != null),
        supports_json_mode: ((.supported_parameters // []) | index("structured_outputs") != null),
        supports_images: ((.architecture.modality // "") | test("image")),
        intelligence_score: (
          if   $p > 0.000004  then 19   # >$4/M    flagship (Opus, GPT-pro)
          elif $p > 0.0000015 then 16   # >$1.5/M  mid (Sonnet, GPT-5, Gemini Pro, Grok)
          elif $p > 0.0000005 then 13   # >$0.5/M  capable (codex, GLM, mini)
          elif $p > 0         then 9    # >$0      cheap (mini-mini, nano)
          else 7                        # free
          end
        )
      }
  ]
}
