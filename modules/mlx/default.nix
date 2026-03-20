{
  config,
  lib,
  pkgs,
  ...
}:
#
# MLX Inference Server Module
#
# Manages the vllm-mlx inference server as a macOS LaunchAgent for Apple Silicon.
# MLX is ~2x faster than Ollama for token generation on M4 Max with ~50% less memory.
#
# Features:
#   - Always-on LaunchAgent running a default MoE model (~70GB, 10B active)
#   - Foreground model switching (auto-restores default on exit)
#   - CLI tools for quick prompts (mlx) and interactive chat (mlx-chat)
#   - OpenAI-compatible API at http://127.0.0.1:11436/v1
#
# Models stored on dedicated APFS volume: /Volumes/HuggingFace
#
let
  cfg = config.programs.mlx;

  # Central vllm-mlx wrapper — single source of truth for the pinned version.
  # The LaunchAgent needs a Nix store path (not a PATH lookup), so the
  # derivation lives here. Also added to home.packages for CLI access.
  vllmMlxPkg = pkgs.writeShellScriptBin "vllm-mlx" ''
    exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==0.2.6" vllm-mlx "$@"
  '';

  apiUrl = "http://${cfg.host}:${toString cfg.port}/v1";
  launchAgentLabel = "dev.vllm-mlx.server";
in
{
  # ============================================================================
  # Configuration Options
  # ============================================================================
  options.programs.mlx = {
    enable = lib.mkEnableOption "MLX inference server via vllm-mlx";

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = "Default HuggingFace model to serve via vllm-mlx";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11436;
      description = "Port for the vllm-mlx API server (default avoids conflicts with ports 11434, 11435, and 8080)";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the vllm-mlx API server";
    };

    huggingFaceHome = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/HuggingFace";
      description = "Path to HuggingFace model cache (dedicated APFS volume)";
    };

    # ---- MLX PERFORMANCE TUNING ----
    # Benchmarked 2026-03-19 on M4 Max 128GB with Qwen3.5-122B-A10B-4bit.
    # Baseline: 55-74 tok/s generation, no parallel request benefit (bandwidth-bound).

    # maxKvSize — Caps rotating KV cache per session (tokens).
    # Prevents kernel panic: IOGPUMemory completeMemory() prepare count underflow
    # on long agentic sessions (58k+ tokens). Critical for 122B models using ~70GB
    # RAM for weights alone — unbounded KV growth crashes the system.
    # Ref: https://github.com/ml-explore/mlx-lm/issues/883
    # Current: 8192 (safe for 128GB with ~50GB headroom)
    # Revisit: increase to 16384-32768 on M4 Ultra 256GB
    maxKvSize = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = "Max KV cache size per session (tokens). Prevents OOM kernel panics on long contexts.";
    };

    # prefillStepSize — Chunk size for prompt prefill processing (tokens).
    # Increasing from default 2048 → 8192 yields ~1.5x TTFT improvement on long prompts.
    # Higher values (16384) are possible but stress memory on 128GB systems.
    # Current: 8192 (balanced speed vs memory for M4 Max 128GB)
    # Revisit: try 16384 after confirming headroom with max-kv-size 8192
    prefillStepSize = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = "Prefill chunk size (tokens). Larger = faster TTFT on long prompts, more memory.";
    };

    # promptCacheSize — Number of distinct KV prefix caches held in LRU.
    # Enables prefix reuse: requests sharing the same system prompt skip re-prefill
    # entirely, yielding up to 5.8x TTFT speedup. Low count because 122B model
    # leaves limited RAM headroom for cached prefixes.
    # Current: 5 (PAL + mlx-chat + local AI consumers = 3 distinct system prompts, plus 2 spare)
    # Revisit: increase if adding more consumers or switching to a smaller model
    promptCacheSize = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Number of distinct prefix KV caches in LRU. Enables fast TTFT for repeated system prompts.";
    };

    # ---- INACTIVE PERFORMANCE OPTIONS ----
    # Documented here for tracking efficiency over time. Each explains why
    # it's disabled and when to revisit.

    # decodeConcurrency — Max requests decoded in parallel (--decode-concurrency).
    # Server default: 32. Benchmarked 2026-03-19: two simultaneous 512-token
    # requests yielded 0.95x speedup (worse than serial). GPU memory bandwidth
    # is fully saturated by a single decode stream on 122B MoE.
    # Revisit: if vllm-mlx adds paged KV cache with true continuous batching,
    # or if switching to a smaller model where bandwidth is not the bottleneck.
    # decodeConcurrency = lib.mkOption {
    #   type = lib.types.int;
    #   default = 32;
    #   description = "Max concurrent decode requests. No benefit for 122B MoE on M4 Max (bandwidth-bound).";
    # };

    # promptConcurrency — Max prompts processed in parallel during prefill (--prompt-concurrency).
    # Server default: 8. Same benchmark result as decodeConcurrency — parallel prefill
    # does not help when one request already saturates memory bandwidth.
    # Revisit: same conditions as decodeConcurrency.
    # promptConcurrency = lib.mkOption {
    #   type = lib.types.int;
    #   default = 8;
    #   description = "Max concurrent prefill requests. No benefit for 122B MoE (bandwidth-bound).";
    # };

    # promptCacheBytes — Max total bytes for all cached KV prefixes (--prompt-cache-bytes).
    # Example: "16G". Not set because count-based promptCacheSize is safer — byte-based
    # requires knowing exact RAM headroom after model loading, which varies by model.
    # Revisit: enable if running many distinct long system prompts that exceed the
    # count limit, or if you want tighter memory control on a constrained system.
    # promptCacheBytes = lib.mkOption {
    #   type = lib.types.nullOr lib.types.str;
    #   default = null;
    #   description = "Max total bytes for prefix caches (e.g. '16G'). Null = unlimited (count-limited instead).";
    # };

    # draftModel — Smaller model for speculative decoding (--draft-model).
    # Speculative decoding has the draft model generate N candidate tokens cheaply,
    # then the main model verifies them in a single forward pass. Can yield 1.5-2x
    # speedup on factual/coding tasks if the draft model has high acceptance rate.
    # Not enabled because it requires pulling, storing, and managing a second model.
    # Candidate: mlx-community/Qwen3-7B-4bit as draft for the 122B target.
    # Revisit: when ready to invest in a second model for throughput gains.
    # draftModel = lib.mkOption {
    #   type = lib.types.nullOr lib.types.str;
    #   default = null;
    #   description = "HuggingFace ID of draft model for speculative decoding. Null = disabled.";
    # };

    # numDraftTokens — Tokens to draft per speculative step (--num-draft-tokens).
    # Server default: 3. Only relevant when draftModel is set. Higher values increase
    # acceptance overhead but can improve throughput if draft quality is high.
    # Revisit: tune after enabling draftModel — start at 3, try 5 if acceptance > 80%.
    # numDraftTokens = lib.mkOption {
    #   type = lib.types.int;
    #   default = 3;
    #   description = "Tokens drafted per speculative step. Only used with draftModel.";
    # };

    # pipeline — Use pipelining instead of tensor parallelism (--pipeline).
    # Only relevant for multi-GPU setups (M4 Ultra with split dies). The M4 Max
    # has a single GPU die, so tensor parallelism and pipelining are equivalent.
    # Revisit: if upgrading to M4 Ultra or a multi-die system.
    # pipeline = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    #   description = "Use pipelining instead of tensor parallelism. Only for multi-GPU (M4 Ultra).";
    # };

    # maxTokens — Default max generation length when client doesn't specify (--max-tokens).
    # Server default: 512. Not overridden because all consumers (PAL, mlx-chat,
    # local AI tools) always pass max_tokens explicitly in their API requests.
    # Setting this would only affect raw curl calls without max_tokens.
    # Revisit: no need unless adding a consumer that omits max_tokens.
    # maxTokens = lib.mkOption {
    #   type = lib.types.int;
    #   default = 512;
    #   description = "Default max tokens when client omits max_tokens. All current consumers set it explicitly.";
    # };
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
    };

    # ==========================================================================
    # CLI Tools
    # ==========================================================================
    home.packages = [
      # vllm-mlx wrapper (on PATH for scripts, store path for LaunchAgent)
      vllmMlxPkg

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
        ProgramArguments = [
          (lib.getExe vllmMlxPkg)
          "serve"
          cfg.defaultModel
          "--port"
          (toString cfg.port)
          "--host"
          cfg.host
          "--max-kv-size"
          (toString cfg.maxKvSize)
          "--prefill-step-size"
          (toString cfg.prefillStepSize)
          "--prompt-cache-size"
          (toString cfg.promptCacheSize)
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
