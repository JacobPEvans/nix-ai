# Cross-Repo Runtime Registry — Pure Data
#
# This is the source of truth for cross-repo shared values: capability-class
# model IDs, well-known endpoints, NodePort allocations. No module-system
# dependencies, no functions, no logic — just an attrset of plain values so
# any consumer (Nix, jq, ansible) can read it without ceremony.
#
# How values reach non-Nix consumers:
#   modules/ai-stack/default.nix activation writes
#   ~/.config/ai-stack/registry.json from `builtins.toJSON (import ./vars/ai-stack.nix)`
#   on every darwin-rebuild. Real file (mode 0644), so users can `vim`/`jq` it
#   for ad-hoc testing — edits revert on next rebuild. For permanent changes,
#   edit this file.
#
# Naming:
#   - models / capability classes: lowercase, hyphenated (`tool-calling`)
#   - endpoints / nodeports: snake_case for jq-friendliness in shell consumers
#
# Adding new fields:
#   - Pure data only. If you reach for `lib.mkOption` or `let ... in`, you're
#     in the wrong file.
#   - Update the schema doc in modules/ai-stack/seed-readme.md (or wherever
#     the README lives) so the JSON shape stays self-explanatory.
{
  # Capability-class registry. Stable consumer-facing names mapped to
  # currently-preferred physical mlx-community/* model IDs. Physical IDs
  # change when we re-benchmark or upstream ships a better quant.
  models = {
    default = "mlx-community/Qwen3.6-35B-A3B-mxfp4";
    quickest = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    tool-calling = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    coding = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
    large-context = "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit";
    most-capable = "mlx-community/Qwen3.5-122B-A10B-4bit";
    oss = "mlx-community/gpt-oss-120b-4bit";
  };

  # Well-known local endpoints. Filled in over Phase 2 as drift sites get
  # migrated from hardcoded literals to registry reads.
  endpoints = {
    mlx_local = "http://localhost:11434";
    bifrost_local = "http://localhost:30080";
  };

  # OrbStack NodePort allocations. Authoritative source for any consumer
  # that needs to know where a service listens.
  nodeports = {
    bifrost = 30080;
    cribl_mcp = 30030;
    otel_grpc = 30317;
    otel_http = 30318;
    cribl_hec = 30088;
    cribl_stream_ui = 30900;
    cribl_edge_ui = 30910;
  };

  # CLI tool versions for non-nix-managed installs (uvx / brew / npm).
  # Renovate updates each entry via the comment hint immediately above it.
  # Per nix-package-placement: nixpkgs first, then brew, then uvx/npm —
  # entries here are tools that fall to brew or uvx because nixpkgs is
  # missing or broken on darwin.
  cliVersions = {
    # cecli — actively maintained Aider fork. PyPI distribution name is
    # `cecli-dev`; entry-point binary is `cecli`. uvx-installed because
    # neither nixpkgs nor homebrew package it.
    # renovate: datasource=pypi depName=cecli-dev
    cecli = "0.99.10";

    # Qwen Code — Alibaba's terminal coding agent. Brew-installed via
    # nix-darwin's homebrew.brews; this pin documents the expected
    # version so consumers can sanity-check what brew has.
    # renovate: datasource=github-releases depName=QwenLM/qwen-code
    qwen-code = "0.15.6";
  };
}
