{
  config,
  lib,
  pkgs,
  ...
}:
#
# MLX Inference Server Module (vllm-mlx 0.2.6)
#
# Manages the vllm-mlx inference server as a macOS LaunchAgent for Apple Silicon.
# MLX is ~2x faster than llama.cpp for token generation on M4 Max with ~50% less memory.
#
# Features:
#   - Always-on LaunchAgent running a default MoE model (~70GB, 10B active)
#   - Foreground model switching (auto-restores default on exit)
#   - CLI tools for quick prompts (mlx) and interactive chat (mlx-chat)
#   - Benchmark suite: throughput (mlx-bench), engine (mlx-bench-engine),
#     raw MLX (mlx-bench-raw), accuracy evaluation (mlx-eval)
#   - OpenAI-compatible API at http://127.0.0.1:11434/v1
#
# Models stored on dedicated APFS volume: /Volumes/HuggingFace
#
# Parameter reference: vllm-mlx 0.2.6 `serve --help` output (captured from local binary).
#
let
  cfg = config.programs.mlx;

  # Pinned version — single source of truth. Shared via mlxShared so
  # benchmark wrappers in packages.nix use the same version.
  vllmMlxVersion = "0.2.6";

  # Central vllm-mlx wrapper — single source of truth for the pinned version.
  # The LaunchAgent needs a Nix store path (not a PATH lookup), so the
  # derivation lives here. Also added to home.packages for CLI access.
  vllmMlxPkg = pkgs.writeShellScriptBin "vllm-mlx" ''
    exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==${vllmMlxVersion}" vllm-mlx "$@"
  '';

  apiUrl = "http://${cfg.host}:${toString cfg.port}/v1";
  launchAgentLabel = "dev.vllm-mlx.server";
in
{
  imports = [
    ./options.nix
    ./packages.nix
    ./launchd.nix
  ];

  # Pass shared bindings to sub-modules via _module.args
  _module.args.mlxShared = {
    inherit
      cfg
      vllmMlxPkg
      vllmMlxVersion
      apiUrl
      launchAgentLabel
      ;
  };
}
