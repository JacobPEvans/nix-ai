#!/usr/bin/env bash
# Seed llama-swap runtime config from the Nix-generated base config.
#
# Called by home.activation on darwin-rebuild switch. Preserves
# runtime-discovered models by only overwriting when the base config
# has actually changed (tracked via .base-config-hash marker file).
#
# Arguments:
#   $1 — path to Nix-generated base config (immutable Nix store)
#   $2 — path to mutable runtime config (read by llama-swap)

base="${1:?Usage: seed-llama-swap-config.sh <base-config> <runtime-config>}"
runtime="${2:?Usage: seed-llama-swap-config.sh <base-config> <runtime-config>}"
runtime_dir="$(dirname "$runtime")"

mkdir -p "$runtime_dir"

base_hash=$(shasum -a 256 "$base" | cut -d' ' -f1)
marker_file="$runtime_dir/.base-config-hash"

if [ ! -f "$runtime" ]; then
  # First activation — seed from base and write hash marker
  cp "$base" "$runtime"
  echo "$base_hash" > "$marker_file"
  echo "Seeded llama-swap runtime config from Nix store"
  exit 0
fi

# Check if base config changed (Nix store hash differs)
prev_hash=""
[ -f "$marker_file" ] && prev_hash=$(cat "$marker_file")

if [ "$base_hash" != "$prev_hash" ]; then
  cp "$base" "$runtime"
  echo "$base_hash" > "$marker_file"
  echo "Updated llama-swap runtime config (base config changed)"
else
  echo "llama-swap runtime config unchanged (base hash matches)"
fi
