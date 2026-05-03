# AI Stack — Role Registry (pure attrset, no module-system dependency)
#
# This file is the single source of truth for role-name → physical model ID
# mappings. It is intentionally a plain attrset so foreign consumers (e.g.
# orbstack-kubernetes Bifrost config) can import it without instantiating the
# home-manager module system.
#
# To reference this registry from Nix flake consumers:
#   inputs.nix-ai.lib.aiStackModels
#
# Role names are stable and consumer-facing. Physical model IDs change when
# we re-benchmark or upstream ships a better quant. All consumers should
# reference role names, not physical names.
{
  default = "mlx-community/Qwen3.6-35B-A3B-mxfp4";
  quickest = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
  tool-calling = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
  coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
  large-context = "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit";
  most-capable = "mlx-community/Qwen3.5-122B-A10B-4bit";
  oss = "mlx-community/gpt-oss-120b-4bit";
}
