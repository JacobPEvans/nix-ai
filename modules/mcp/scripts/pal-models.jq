# pal-models.jq
#
# Transforms Ollama /api/tags JSON → PAL MCP custom_models.json format.
# Usage: curl -sf http://localhost:11434/api/tags | jq --from-file pal-models.jq
#
# Behaviour:
#   - Skips models with "/" in name (OpenRouter/proxy entries)
#   - model_name: base name for :latest, full name for tagged variants
#   - aliases: base name always included; hyphenated variant added for non-latest tags
#   - intelligence_score: estimated from model size (GB buckets)
#   - Cloud/remote models (size 0): intelligence_score 14
#   - Deduplication: first model to claim an alias wins; later models lose that alias

{
  custom_api: {
    models: (
      [
        .models[]
        | select(.name | contains("/") | not)
        | .name as $name
        | ($name | split(":")[0]) as $base
        | ($name | split(":")[1] // "latest") as $tag
        | (if $tag == "latest" then $base else $name end) as $model_name
        | (.size / 1073741824) as $gb
        | (if $gb == 0 then 14
           elif $gb < 5 then 5
           elif $gb < 20 then 8
           elif $gb < 40 then 11
           elif $gb < 70 then 14
           else 17 end) as $score
        | {
            model_name: $model_name,
            aliases: (
              if $tag == "latest" then [$base]
              else [$base, "\($base)-\($tag)"]
              end
            ),
            intelligence_score: $score,
            speed_score: 5,
            json_mode: false,
            function_calling: false,
            images: false
          }
      ]
      | reduce .[] as $m (
          {seen: [], out: []};
          .seen as $seen
          | .out as $out
          | $m
          | .aliases |= map(select(. as $a | $seen | index($a) | not))
          | . as $cleaned
          | {
              seen: ($seen + $cleaned.aliases),
              out: ($out + [$cleaned])
            }
        )
      | .out
    )
  }
}
