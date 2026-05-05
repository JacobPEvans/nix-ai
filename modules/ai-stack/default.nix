# AI Stack — Role Registry
#
# Single source of truth mapping role names → physical mlx-community/* model
# IDs. Role names are stable and consumer-facing; physical model IDs change
# whenever we re-benchmark or upstream ships a better quant.
#
# All consumers (llama-swap, fabric, pal-mcp, screenpipe presets, zsh
# aliases) reference roles, not physical names. Swapping a role's model is
# then one Nix attr edit + a darwin-rebuild switch — no consumer-side change
# is required.
#
# The role names mirror the screenpipe preset taxonomy (default, quickest,
# tool-calling, coding, large-context, most-capable) plus oss for explicit
# Apache-2/MIT model preference. Add new roles here; do not embed physical
# names in consumer modules.
#
# vars/ai-stack.nix is the data file (models + endpoints + nodeports). The
# home-manager activation below serializes it to ~/.config/ai-stack/registry.json
# on every rebuild so non-Nix consumers (orbstack-kubernetes, ansible, shell
# scripts) can read the same values via plain `jq`.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  registryAttrs = import ../../vars/ai-stack.nix;
  registryJson = pkgs.writeText "ai-stack-registry.json" (builtins.toJSON registryAttrs);
in
{
  options.services.aiStack.models = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = import ../../lib/ai-stack-models.nix;
    description = ''
      Role-name → physical mlx-community/* model ID. Each role becomes a
      first-class llama-swap entry whose cmd runs `vllm-mlx serve <physical>`.
      Physical names also remain queryable for direct curl / debugging.

      The default reads from vars/ai-stack.nix. To change the registry,
      edit that file. Override here only when a consumer needs a private
      mapping that should not propagate to ~/.config/ai-stack/registry.json.
    '';
  };

  config.home.activation.writeAiStackRegistry = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.config/ai-stack/registry.json"
    $DRY_RUN_CMD mkdir -p "$(dirname "$target")"
    $DRY_RUN_CMD install -m 0644 ${registryJson} "$target"
  '';
}
