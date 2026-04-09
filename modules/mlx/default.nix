{
  config,
  lib,
  pkgs,
  ...
}:
#
# MLX Inference Server Module (vllm-mlx 0.2.6 + llama-swap proxy)
#
# Manages the MLX inference stack as a macOS LaunchAgent for Apple Silicon.
# MLX is ~2x faster than llama.cpp for token generation on M4 Max with ~50% less memory.
#
# Architecture:
#   - llama-swap proxy listens on the API port (11434) and manages vllm-mlx backends
#   - vllm-mlx child processes start on ephemeral ports (11436+)
#   - Model switching is transparent: send model: "X" and the proxy handles the swap
#   - Default model is preloaded at startup; additional models load on demand
#
# Features:
#   - Always-on LaunchAgent with llama-swap proxy managing vllm-mlx backends
#   - Transparent model switching (no process management required)
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

  # Pinned versions — single source of truth. Shared via mlxShared so
  # packages.nix uses the same values without duplication.
  # renovate: datasource=pypi depName=vllm-mlx
  vllmMlxVersion = "0.2.7";
  # renovate: datasource=pypi depName=parakeet-mlx
  parakeetMlxVersion = "0.5.1";
  # renovate: datasource=pypi depName=mlx-vlm
  mlxVlmVersion = "0.4.3";

  # Central vllm-mlx wrapper — single source of truth for the pinned version.
  # The LaunchAgent needs a Nix store path (not a PATH lookup), so the
  # derivation lives here. Also added to home.packages for CLI access.
  vllmMlxPkg = pkgs.writeShellScriptBin "vllm-mlx" ''
    exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==${vllmMlxVersion}" vllm-mlx "$@"
  '';

  # llama-swap proxy package — sits on the API port, manages vllm-mlx child processes.
  llamaSwapPkg = pkgs.llama-swap;

  apiUrl = "http://${cfg.host}:${toString cfg.port}/v1";
  launchAgentLabel = "dev.vllm-mlx.server";

  # Mutable runtime config path — llama-swap reads this with --watch-config.
  # mlx-discover merges auto-discovered models into this file at runtime.
  # The Nix-generated llamaSwapConfigFile seeds this on first activation.
  llamaSwapRuntimeConfigPath = "${config.home.homeDirectory}/.config/mlx/llama-swap.json";

  # Build the vllm-mlx serve command string for a given model ID.
  # NOTE: \${PORT} is a llama-swap template macro — must be escaped to prevent
  # Nix string interpolation from consuming it before the config is written.
  mkVllmCmd =
    modelId:
    let
      baseCmd = "${lib.getExe vllmMlxPkg} serve ${modelId} --port \${PORT} --host ${cfg.host}";
      flags = lib.concatStringsSep " " (
        lib.optionals (cfg.cacheMemoryMb != null) [
          "--cache-memory-mb"
          (toString cfg.cacheMemoryMb)
        ]
        ++ lib.optionals (cfg.prefillBatchSize != null) [
          "--prefill-batch-size"
          (toString cfg.prefillBatchSize)
        ]
        ++ lib.optionals cfg.continuousBatching [ "--continuous-batching" ]
        ++ lib.optionals (cfg.maxNumSeqs != null) [
          "--max-num-seqs"
          (toString cfg.maxNumSeqs)
        ]
        ++ lib.optionals (cfg.chunkedPrefillTokens != null) [
          "--chunked-prefill-tokens"
          (toString cfg.chunkedPrefillTokens)
        ]
        ++ lib.optionals (cfg.completionBatchSize != null) [
          "--completion-batch-size"
          (toString cfg.completionBatchSize)
        ]
        ++ lib.optionals cfg.enableAutoToolChoice [ "--enable-auto-tool-choice" ]
        ++ lib.optionals (cfg.enableAutoToolChoice && cfg.toolCallParser != null) [
          "--tool-call-parser"
          cfg.toolCallParser
        ]
        ++ lib.optionals (cfg.reasoningParser != null) [
          "--reasoning-parser"
          cfg.reasoningParser
        ]
      );
    in
    "${baseCmd}${lib.optionalString (flags != "") " ${flags}"}";

  # Default model entry — always loaded at startup, never auto-unloaded.
  defaultModelEntry = {
    cmd = mkVllmCmd cfg.defaultModel;
    ttl = 0;
    env = [ "HF_HOME=${cfg.huggingFaceHome}" ];
    checkEndpoint = "/v1/models";
  };

  # Additional model entries from cfg.models — loaded on demand, unloaded after idleTtl.
  additionalModels = lib.mapAttrs (
    name: modelCfg:
    {
      cmd =
        mkVllmCmd name
        + lib.optionalString (modelCfg.extraArgs != [ ]) (
          " " + lib.concatStringsSep " " modelCfg.extraArgs
        );
      ttl = if modelCfg.ttl > 0 then modelCfg.ttl else cfg.proxy.idleTtl;
      env = [ "HF_HOME=${cfg.huggingFaceHome}" ];
      checkEndpoint = "/v1/models";
    }
    // lib.optionalAttrs (modelCfg.aliases != [ ]) {
      inherit (modelCfg) aliases;
    }
  ) cfg.models;

  allModels = {
    "${cfg.defaultModel}" = defaultModelEntry;
  }
  // additionalModels;

  llamaSwapConfigAttrs = {
    inherit (cfg.proxy) healthCheckTimeout;
    logLevel = "info";
    startPort = 11436;

    models = allModels;

    groups.mlx-models = {
      swap = true;
      exclusive = true;
      members = builtins.attrNames allModels;
    };

    hooks.on_startup.preload = [ cfg.defaultModel ];
  };

  # Use pkgs.writeText (not builtins.toFile) because content references store paths
  # (vllmMlxPkg store path is embedded in the cmd strings).
  llamaSwapConfigFile = pkgs.writeText "llama-swap-config.json" (
    builtins.toJSON llamaSwapConfigAttrs
  );
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
      parakeetMlxVersion
      mlxVlmVersion
      apiUrl
      launchAgentLabel
      llamaSwapPkg
      llamaSwapConfigFile
      llamaSwapConfigAttrs
      llamaSwapRuntimeConfigPath
      ;
  };
}
