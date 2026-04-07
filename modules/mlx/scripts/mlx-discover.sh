#!/usr/bin/env bash
# Auto-discover downloaded MLX models and register them with llama-swap.
#
# Scans the HuggingFace cache for downloaded models, merges them into the
# llama-swap runtime config, and writes the result to the mutable config path.
# llama-swap's --watch-config flag auto-reloads when the file changes.
#
# Usage:
#   mlx-discover            # Discover and register all fitting models
#   mlx-discover --quiet    # Suppress informational output
#   mlx-discover --dry-run  # Show what would be registered without writing

hf_home="${MLX_HF_HOME:-/Volumes/HuggingFace}"
config_path="${MLX_LLAMA_SWAP_CONFIG:?MLX_LLAMA_SWAP_CONFIG not set}"
base_config="${MLX_LLAMA_SWAP_BASE_CONFIG:?MLX_LLAMA_SWAP_BASE_CONFIG not set}"

quiet=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --quiet) quiet=true ;;
    --dry-run) dry_run=true ;;
  esac
done

# Ensure base config exists
if [ ! -f "$base_config" ]; then
  echo "ERROR: Base config not found at $base_config" >&2
  echo "Run darwin-rebuild switch to generate it." >&2
  exit 1
fi

# Seed runtime config from base if it doesn't exist
if [ ! -f "$config_path" ]; then
  mkdir -p "$(dirname "$config_path")"
  cp "$base_config" "$config_path"
fi

# Read current runtime config
current_config=$(cat "$config_path")

# Extract the vllm-mlx command template from the default model entry.
# We reuse the same binary path and flags for discovered models.
default_model=$(echo "$current_config" | jq -r '.hooks.on_startup.preload[0] // empty')
if [ -z "$default_model" ]; then
  echo "ERROR: Could not determine default model from config" >&2
  exit 1
fi

# Extract the cmd template: replace the model ID with a placeholder so we can
# substitute discovered model IDs into the same command structure.
cmd_template=$(echo "$current_config" | jq -r --arg m "$default_model" '.models[$m].cmd // empty')
if [ -z "$cmd_template" ]; then
  echo "ERROR: Could not extract command template from default model entry" >&2
  exit 1
fi

# Extract shared env and checkEndpoint from default model
model_env=$(echo "$current_config" | jq -c --arg m "$default_model" '.models[$m].env // []')
check_endpoint=$(echo "$current_config" | jq -r --arg m "$default_model" '.models[$m].checkEndpoint // "/v1/models"')
idle_ttl=$(echo "$current_config" | jq -r '.idleTtl // 1800')

# Memory budget
total_bytes=$(sysctl -n hw.memsize)
total_gb=$(( total_bytes / 1073741824 ))
available_gb=$(( total_gb - 20 ))

# Patterns to exclude (non-generative models)
exclude_pattern="(whisper|FLUX|Embedding|embedding|TTS|tts|OCR|ocr|CLIP|clip|siglip|bert|bge-|e5-|gte-|nomic-embed|jina-embed)"

discovered=0
skipped=0

# Build the list of new model entries as a JSON object
new_models="{}"
new_members="[]"

for model_dir in "$hf_home/hub"/models--mlx-community--*; do
  [ -d "$model_dir" ] || continue

  # Convert cache path to HuggingFace model ID
  dir_name=$(basename "$model_dir")
  model_id="${dir_name#models--}"
  model_id="${model_id//--//}"

  # Skip non-generative models
  if echo "$model_id" | grep -qEi "$exclude_pattern"; then
    $quiet || echo "SKIP: $model_id (non-generative)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # Skip if already in config
  if echo "$current_config" | jq -e --arg m "$model_id" '.models[$m]' > /dev/null 2>&1; then
    $quiet || echo "SKIP: $model_id (already registered)" >&2
    continue
  fi

  # Memory preflight
  read -r model_gb estimated_gb < <(
    du -sk "$model_dir" | awk '{
      gb = int($1 / 1048576 + 0.5)
      est = int(gb * 1.3 + 0.5)
      print gb, est
    }'
  )

  if [ "$estimated_gb" -gt "$available_gb" ]; then
    $quiet || echo "SKIP: $model_id (${estimated_gb} GB est. > ${available_gb} GB available)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # Generate command by substituting model ID into the template.
  # The template has the default model's ID after "serve " — replace it.
  model_cmd="${cmd_template//serve $default_model/serve $model_id}"

  # Build model entry JSON
  entry=$(jq -n \
    --arg cmd "$model_cmd" \
    --argjson ttl "$idle_ttl" \
    --argjson env "$model_env" \
    --arg ep "$check_endpoint" \
    '{cmd: $cmd, ttl: $ttl, env: $env, checkEndpoint: $ep}')

  new_models=$(echo "$new_models" | jq --arg m "$model_id" --argjson e "$entry" '. + {($m): $e}')
  new_members=$(echo "$new_members" | jq --arg m "$model_id" '. + [$m]')

  $quiet || echo "ADD:  $model_id (${model_gb} GB disk, ${estimated_gb} GB est.)"
  discovered=$((discovered + 1))
done

if [ "$discovered" -eq 0 ]; then
  $quiet || echo "No new models to register (${skipped} skipped)."
  exit 0
fi

if $dry_run; then
  echo "DRY RUN: Would register $discovered new models:"
  echo "$new_models" | jq -r 'keys[]'
  exit 0
fi

# Merge new models into the runtime config:
# 1. Add model entries to .models
# 2. Add model IDs to .groups.mlx-models.members
merged=$(echo "$current_config" | jq \
  --argjson new_models "$new_models" \
  --argjson new_members "$new_members" \
  '.models += $new_models |
   .groups."mlx-models".members = (.groups."mlx-models".members + $new_members | unique)')

# Write atomically (write to tmp, then mv)
tmp_config="${config_path}.tmp.$$"
echo "$merged" | jq '.' > "$tmp_config"
mv "$tmp_config" "$config_path"

$quiet || echo ""
$quiet || echo "Registered $discovered new models ($skipped skipped)."
$quiet || echo "llama-swap will auto-reload the config."
