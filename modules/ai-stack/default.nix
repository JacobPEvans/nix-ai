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

{ lib, ... }:
{
  options.services.aiStack.models = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {
      default = "mlx-community/Qwen3.6-35B-A3B-mxfp4";
      quickest = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
      tool-calling = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
      coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
      large-context = "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit";
      most-capable = "mlx-community/Qwen3.5-122B-A10B-4bit";
      oss = "mlx-community/gpt-oss-120b-4bit";
    };
    description = ''
      Role-name → physical mlx-community/* model ID. Each role becomes a
      first-class llama-swap entry whose cmd runs `vllm-mlx serve <physical>`.
      Physical names also remain queryable for direct curl / debugging.

      This is the ONLY place real MLX model strings should live in the Nix
      tree. Consumer modules (fabric.defaultModel, pal-mcp CUSTOM_MODEL_NAME,
      screenpipe presets, zsh aliases) reference role names instead.
    '';
  };
}
