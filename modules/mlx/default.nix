{
  config,
  lib,
  pkgs,
  ...
}:
#
# MLX Inference Server Module
#
# Manages an MLX inference server as a macOS LaunchAgent for Apple Silicon.
# Supports two backends: vllm-mlx (faster for MoE) and mlx-lm (Apple's reference server).
# Only one backend runs at a time via the `backend` option.
#
# Features:
#   - Always-on LaunchAgent running a default MoE model (~70GB, 10B active)
#   - Foreground model switching (auto-restores default on exit)
#   - CLI tools for quick prompts (mlx) and interactive chat (mlx-chat)
#   - OpenAI-compatible API at http://127.0.0.1:11434/v1
#
# Models stored on dedicated APFS volume: /Volumes/HuggingFace
#
let
  cfg = config.programs.mlx;

  # vllm-mlx wrapper — pinned version, Nix store path for LaunchAgent.
  vllmMlxPkg = pkgs.writeShellScriptBin "vllm-mlx" ''
    exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==0.2.6" vllm-mlx "$@"
  '';

  # mlx-lm wrapper — pinned version, Nix store path for LaunchAgent.
  mlxLmPkg = pkgs.writeShellScriptBin "mlx-lm-server" ''
    exec ${pkgs.uv}/bin/uvx --from "mlx-lm==0.31.1" mlx_lm.server "$@"
  '';

  apiUrl = "http://${cfg.host}:${toString cfg.port}/v1";
  launchAgentLabel = "dev.vllm-mlx.server";
in
{
  # ============================================================================
  # Configuration Options
  # ============================================================================
  options.programs.mlx = {
    enable = lib.mkEnableOption "MLX inference server";

    backend = lib.mkOption {
      type = lib.types.enum [
        "vllm-mlx"
        "mlx-lm"
      ];
      default = "vllm-mlx";
      description = "Inference backend. vllm-mlx = faster for MoE, mlx-lm = Apple's reference server.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = "Default HuggingFace model to serve";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the API server (avoids conflict with 8080 used by Open WebUI)";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the API server";
    };

    huggingFaceHome = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/HuggingFace";
      description = "Path to HuggingFace model cache (dedicated APFS volume)";
    };

    # ---- vllm-mlx 0.2.6 SETTINGS ----
    # Benchmarked 2026-03-19 on M4 Max 128GB with Qwen3.5-122B-A10B-4bit.
    # Baseline: 55-74 tok/s generation, no parallel request benefit (bandwidth-bound).
    vllmMlxSettings = {

      # chunkedPrefillTokens — Max prefill tokens per scheduler step (--chunked-prefill-tokens).
      # Prevents starvation of active decode requests during long prefills by chunking
      # the prefill into smaller steps. 0 = disabled (process entire prefill at once).
      # Current: 8192 (balanced speed vs memory for M4 Max 128GB)
      # Revisit: try 16384 after confirming headroom, or 0 to disable chunking
      chunkedPrefillTokens = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 8192;
        description = "Max prefill tokens per scheduler step (--chunked-prefill-tokens). 0 = disabled.";
      };

      # cacheMemoryMb — Hard cap on KV cache memory (--cache-memory-mb).
      # Prevents kernel panic: IOGPUMemory completeMemory() prepare count underflow
      # on long agentic sessions (58k+ tokens). Critical for 122B models using ~70GB
      # RAM for weights alone — unbounded KV growth crashes the system.
      # Ref: https://github.com/ml-explore/mlx-lm/issues/883
      # vllm-mlx default: auto-detect ~20% of RAM (~25GB on 128GB). We keep the default
      # since 25GB is reasonable headroom above the ~70GB model weight footprint.
      # Revisit: set explicitly if OOM occurs, or increase on M4 Ultra 256GB.
      cacheMemoryMb = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Hard cap on KV cache memory in MB (--cache-memory-mb). Null = auto-detect ~20% of RAM.";
      };

      # prefixCacheSize — Number of distinct KV prefix caches held in LRU (--prefix-cache-size).
      # Enables prefix reuse: requests sharing the same system prompt skip re-prefill
      # entirely, yielding up to 5.8x TTFT speedup. Only used in legacy (non-memory-aware)
      # cache mode. vllm-mlx 0.2.6 defaults to memory-aware cache which auto-manages entries.
      # Current: null (use vllm-mlx default of 100 with memory-aware cache)
      # Revisit: set explicitly with --no-memory-aware-cache for deterministic behavior
      prefixCacheSize = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Max entries in prefix cache (--prefix-cache-size). Null = use server default (100, legacy mode only).";
      };
    };

    # ---- mlx-lm 0.31.1 SETTINGS ----
    mlxLmSettings = {

      # prefillStepSize — Chunk size for prompt prefill processing (--prefill-step-size).
      # mlx-lm default: 2048. Increasing to 8192 yields ~1.5x TTFT improvement on long prompts.
      # Revisit: try 16384 after confirming memory headroom
      prefillStepSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8192;
        description = "Prefill chunk size in tokens (--prefill-step-size). Larger = faster TTFT on long prompts.";
      };

      # promptCacheSize — Number of distinct KV prefix caches held in LRU (--prompt-cache-size).
      # mlx-lm default: not set. Enables prefix reuse for repeated system prompts.
      promptCacheSize = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Max entries in prompt cache (--prompt-cache-size). Null = server default.";
      };

      # promptCacheBytes — Max total bytes for all cached KV prefixes (--prompt-cache-bytes).
      # Example: "16G". Not set because count-based promptCacheSize is safer.
      promptCacheBytes = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Max total bytes for prompt caches (e.g. '16G'). Null = unlimited.";
      };

      # decodeConcurrency — Max requests decoded in parallel (--decode-concurrency).
      # mlx-lm default: 32. Benchmarked 2026-03-19: no benefit for 122B MoE (bandwidth-bound).
      decodeConcurrency = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Max concurrent decode requests (--decode-concurrency). Null = server default.";
      };

      # promptConcurrency — Max prompts processed in parallel during prefill (--prompt-concurrency).
      # mlx-lm default: 8. No benefit for 122B MoE (bandwidth-bound).
      promptConcurrency = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Max concurrent prefill requests (--prompt-concurrency). Null = server default.";
      };
    };
  };

  # ============================================================================
  # Implementation
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # Environment Variables
    # ==========================================================================
    home.sessionVariables = {
      MLX_API_URL = apiUrl;
      MLX_DEFAULT_MODEL = cfg.defaultModel;
      MLX_PORT = toString cfg.port;
      MLX_HOST = cfg.host;
      MLX_HF_HOME = cfg.huggingFaceHome;
      MLX_BACKEND = cfg.backend;
    };

    # ==========================================================================
    # CLI Tools
    # ==========================================================================
    home.packages = [
      # Both backend wrappers on PATH for manual CLI use
      vllmMlxPkg
      mlxLmPkg

      # mlx — one-shot prompt (curl + jq, no Python)
      (pkgs.writeShellApplication {
        name = "mlx";
        runtimeInputs = with pkgs; [
          curl
          jq
        ];
        text = builtins.readFile ./scripts/mlx.sh;
      })

      # mlx-switch — foreground model swap, auto-restores default on Ctrl-C
      (pkgs.writeShellApplication {
        name = "mlx-switch";
        runtimeInputs = with pkgs; [
          lsof
          vllmMlxPkg
        ];
        text = builtins.readFile ./scripts/mlx-switch.sh;
      })

      # mlx-default — safety net to restore the default LaunchAgent
      (pkgs.writeShellApplication {
        name = "mlx-default";
        runtimeInputs = with pkgs; [ lsof ];
        text = builtins.readFile ./scripts/mlx-default.sh;
      })

      # mlx-status — show running model, memory, uptime, LaunchAgent state
      (pkgs.writeShellApplication {
        name = "mlx-status";
        runtimeInputs = with pkgs; [
          curl
          jq
          lsof
          bc
        ];
        text = builtins.readFile ./scripts/mlx-status.sh;
      })

      # mlx-chat — interactive multi-turn chat via openai SDK
      (pkgs.writeShellScriptBin "mlx-chat" ''
        exec ${pkgs.uv}/bin/uv run \
          --with "openai==1.82.0" \
          python3 ${./scripts/mlx-chat.py} "$@"
      '')
    ];

    # ==========================================================================
    # LaunchAgent for Auto-Start
    # ==========================================================================
    launchd.agents.vllm-mlx = {
      enable = true;
      config = {
        Label = launchAgentLabel;
        ProgramArguments =
          if cfg.backend == "vllm-mlx" then
            [
              (lib.getExe vllmMlxPkg)
              "serve"
              cfg.defaultModel
              "--port"
              (toString cfg.port)
              "--host"
              cfg.host
              "--chunked-prefill-tokens"
              (toString cfg.vllmMlxSettings.chunkedPrefillTokens)
            ]
            ++ lib.optionals (cfg.vllmMlxSettings.cacheMemoryMb != null) [
              "--cache-memory-mb"
              (toString cfg.vllmMlxSettings.cacheMemoryMb)
            ]
            ++ lib.optionals (cfg.vllmMlxSettings.prefixCacheSize != null) [
              "--prefix-cache-size"
              (toString cfg.vllmMlxSettings.prefixCacheSize)
            ]
          else
            [
              (lib.getExe mlxLmPkg)
              "--model"
              cfg.defaultModel
              "--port"
              (toString cfg.port)
              "--host"
              cfg.host
              "--prefill-step-size"
              (toString cfg.mlxLmSettings.prefillStepSize)
            ]
            ++ lib.optionals (cfg.mlxLmSettings.promptCacheSize != null) [
              "--prompt-cache-size"
              (toString cfg.mlxLmSettings.promptCacheSize)
            ]
            ++ lib.optionals (cfg.mlxLmSettings.promptCacheBytes != null) [
              "--prompt-cache-bytes"
              cfg.mlxLmSettings.promptCacheBytes
            ]
            ++ lib.optionals (cfg.mlxLmSettings.decodeConcurrency != null) [
              "--decode-concurrency"
              (toString cfg.mlxLmSettings.decodeConcurrency)
            ]
            ++ lib.optionals (cfg.mlxLmSettings.promptConcurrency != null) [
              "--prompt-concurrency"
              (toString cfg.mlxLmSettings.promptConcurrency)
            ];
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          HF_HOME = cfg.huggingFaceHome;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.error.log";
      };
    };
  };
}
