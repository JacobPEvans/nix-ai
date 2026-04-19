#
# MLX Module — Option Declarations
#
# All `options.programs.mlx` declarations live here.
# Active options are defined normally; inactive options are commented out
# with rationale for why they're disabled and when to revisit.
#
{ lib, ... }:
{
  options.programs.mlx = {
    enable = lib.mkEnableOption "MLX inference server via vllm-mlx";

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-35B-A3B-4bit";
      description = ''
        Default mlx-community/ HuggingFace model to serve via vllm-mlx.
        Benchmark-driven rationale and historical default-swap context live
        on the companion dataset:
        https://huggingface.co/datasets/JacobPEvans/mlx-benchmarks
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the vllm-mlx API server (avoids conflict with 8080 used by Open WebUI)";
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

    # ---- vllm-mlx 0.2.6 PERFORMANCE TUNING ----
    # Benchmarked 2026-03-19 on M4 Max 128GB with Qwen3.5-122B-A10B-4bit (~65 GB).
    # Memory budgets below reference the 122B MoE model (10B active params, ~20 GB).
    # Baseline: 55-74 tok/s generation, no parallel request benefit (bandwidth-bound).
    #
    # vllm-mlx 0.2.6 replaced the old token-count KV cache (--max-kv-size) with a
    # memory-aware cache that auto-sizes based on available RAM and evicts via LRU.
    # The server default allocates ~20% of RAM (~25.6GB on 128GB), which combined
    # with ~65GB model weights consumes ~90GB — leaving only ~38GB for macOS + apps.
    # With 10+ Claude Code sessions this caused V8 OOM crashes and swap exhaustion.

    # cacheMemoryMb — Override the memory-aware cache size (--cache-memory-mb).
    # Default: 16384 (16GB). Balances prefix cache reuse with OOM prevention.
    # With a 65GB model, 16GB cache uses ~81GB total, leaving ~47GB on 128GB systems
    # for macOS + 3 Claude Code sessions. If MLX ever causes another OOM, lower to 8192.
    # Set to null to restore server auto-detect (~20% RAM = ~25.6GB — too aggressive).
    # Prevents kernel panic: IOGPUMemory completeMemory() prepare count underflow
    # on long agentic sessions (58k+ tokens).
    # Ref: https://github.com/ml-explore/mlx-lm/issues/883
    cacheMemoryMb = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 16384;
      description = "Cache memory limit in MB. Null = auto-detect (~20% RAM). Default 16GB prevents OOM with large models. Lower to 8192 if OOM recurs.";
    };

    # prefillBatchSize — Batch size for prompt prefill processing (--prefill-batch-size).
    # Default: null = server picks optimal value based on available memory.
    # Previously --prefill-step-size; renamed in v0.2.6.
    # Larger values can improve TTFT on long prompts but increase memory pressure.
    # Revisit: benchmark specific values if TTFT is a concern.
    prefillBatchSize = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Prefill batch size (tokens). Null = server default. Larger = faster TTFT, more memory.";
    };

    # ---- CONCURRENCY & BATCHING OPTIONS (vllm-mlx 0.2.6) ----
    # Complete parameter reference from `vllm-mlx serve --help`.
    # Each option explains what it does, the server default, why it defaults to off,
    # and when to enable it. All configurable but off by default — enable in
    # nix-darwin config to benchmark concurrent query performance.

    # ---- ACTIVE TUNING (uncomment to override server defaults) ----

    # cacheMemoryPercent — Fraction of available RAM for cache (--cache-memory-percent).
    # Server default: 0.20. Alternative to cacheMemoryMb for proportional sizing.
    # Disabled: auto-detect (20%) is appropriate for 128GB with a 70GB model.
    # Revisit: if switching models or needing finer memory control.
    # cacheMemoryPercent = lib.mkOption {
    #   type = lib.types.nullOr lib.types.float;
    #   default = null;
    #   description = "Fraction of RAM for cache (0.0-1.0). Alternative to cacheMemoryMb.";
    # };

    # continuousBatching — Enable continuous batching (--continuous-batching).
    # Server default: disabled. Improves multi-user throughput by interleaving
    # prefill and decode across requests, but adds scheduling overhead for
    # single-user workloads (~5% slower per-request in isolation).
    # Default: false. Enable to benchmark concurrent query throughput.
    continuousBatching = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable continuous batching. Better multi-user throughput, slight single-user overhead.";
    };

    # maxNumSeqs — Max concurrent sequences (--max-num-seqs).
    # Server default: unset (no limit). Caps parallel request handling.
    # Default: null (no limit). Set to 2-8 when enabling continuousBatching
    # to control memory pressure from concurrent requests.
    maxNumSeqs = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Max concurrent sequences. Null = no limit. Set with continuousBatching.";
    };

    # chunkedPrefillTokens — Max prefill tokens per scheduler step (--chunked-prefill-tokens).
    # Server default: 0 (disabled). Prevents prefill starvation in multi-request
    # scenarios by limiting how many tokens are prefilled before yielding to decode.
    # Default: null (disabled). Set to 256-2048 when enabling continuousBatching.
    chunkedPrefillTokens = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = "Max prefill tokens per scheduler step. 0 = disabled. Prevents prefill starvation.";
    };

    # completionBatchSize — Completion batch size (--completion-batch-size).
    # Server default: unset. Controls decode batching — how many tokens are
    # generated per decode step across concurrent sequences.
    # Default: null (server default). Tune alongside maxNumSeqs.
    completionBatchSize = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Completion batch size. Null = server default. Tune with continuousBatching.";
    };

    # streamInterval — Tokens to batch before streaming (--stream-interval).
    # Server default: unset. 1 = smooth streaming, higher = more throughput.
    # Disabled: server default is fine for agentic workloads.
    # Revisit: if latency-sensitive streaming is needed (set to 1).
    # streamInterval = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Tokens batched before streaming. 1 = smooth, higher = throughput.";
    # };

    # maxTokens — Default max generation length (--max-tokens).
    # Server default: 32768. Only affects requests that omit max_tokens.
    # Disabled: all consumers (PAL, mlx-chat, local AI tools) set max_tokens explicitly.
    # Revisit: no need unless adding a consumer that omits max_tokens.
    # maxTokens = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Default max tokens when client omits max_tokens. Server default: 32768.";
    # };

    # defaultTemperature — Override default temperature (--default-temperature).
    # Server default: model-dependent. Overrides for all requests without explicit temperature.
    # Disabled: consumers set temperature explicitly.
    # Revisit: only if a consumer relies on server defaults.
    # defaultTemperature = lib.mkOption {
    #   type = lib.types.nullOr lib.types.float;
    #   default = null;
    #   description = "Override default temperature for requests that don't set it.";
    # };

    # defaultTopP — Override default top_p (--default-top-p).
    # Server default: model-dependent.
    # Disabled: consumers set top_p explicitly.
    # Revisit: same as defaultTemperature.
    # defaultTopP = lib.mkOption {
    #   type = lib.types.nullOr lib.types.float;
    #   default = null;
    #   description = "Override default top_p for requests that don't set it.";
    # };

    # timeout — Request timeout in seconds (--timeout).
    # Server default: 300. Per-request timeout.
    # Disabled: 300s is generous for agentic workloads.
    # Revisit: increase if running very long generation requests.
    # timeout = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Request timeout in seconds. Server default: 300.";
    # };

    # ---- EXPERIMENTAL ----

    # pagedCache — Use paged KV cache (--use-paged-cache).
    # Server default: disabled. Experimental paged cache implementation.
    # Disabled: experimental, memory-aware cache is production-ready.
    # Revisit: when paged cache graduates from experimental.
    # pagedCache = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    #   description = "Use experimental paged KV cache.";
    # };

    # pagedCacheBlockSize — Tokens per cache block (--paged-cache-block-size).
    # Server default: 64. Only used with pagedCache.
    # Disabled: pagedCache is experimental.
    # Revisit: when enabling pagedCache.
    # pagedCacheBlockSize = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Tokens per paged cache block. Server default: 64. Only with pagedCache.";
    # };

    # maxCacheBlocks — Maximum cache blocks (--max-cache-blocks).
    # Server default: 1000. Only used with pagedCache.
    # Disabled: pagedCache is experimental.
    # Revisit: when enabling pagedCache.
    # maxCacheBlocks = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Maximum paged cache blocks. Server default: 1000. Only with pagedCache.";
    # };

    # ---- TOOL INTEGRATION ----
    # Server-side tool calling returns structured tool_calls in OpenAI API responses.
    # Without these flags, streaming tool calls are broken (raw XML leaks as text)
    # and non-streaming relies on a fragile generic parser.

    # enableAutoToolChoice — Activate model-specific tool call parsing (--enable-auto-tool-choice).
    # No-op when request has no `tools` parameter, so safe to leave on.
    # Default: true — primary use case is tool calling via PAL MCP.
    enableAutoToolChoice = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic tool choice for supported models. No-op when request has no tools.";
    };

    # toolCallParser — Tool call parser (--tool-call-parser).
    # Default: "hermes" — handles Nemotron XML format (<tool_call><function=...>)
    # that Qwen3.5 produces, and supports native tool format for multi-turn
    # conversations. Override to "auto", "qwen3_coder", etc. if needed.
    toolCallParser = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "auto"
          "mistral"
          "qwen"
          "qwen3_coder"
          "llama"
          "hermes"
          "deepseek"
          "kimi"
          "granite"
          "nemotron"
          "xlam"
          "functionary"
          "glm47"
        ]
      );
      default = "hermes";
      description = "Tool call parser. Only used with enableAutoToolChoice. 'hermes' handles Nemotron XML (<tool_call><function=...>) and supports native tool format for multi-turn conversations.";
    };

    # reasoningParser — Reasoning content extraction (--reasoning-parser).
    # Extracts <think>...</think> into structured reasoning_content field.
    # DISABLED: vllm-mlx 0.2.6 has a bug where --reasoning-parser and
    # --tool-call-parser are mutually exclusive in streaming mode (server.py
    # L1920-1946 bypasses the tool parser when reasoning parser is active).
    # This breaks any consumer relying on streaming tool_calls (e.g., agent
    # frameworks that send stream:true with tools and expect structured
    # choice.delta.tool_calls in SSE chunks).
    # Without this flag, <think> blocks still appear in content text — most
    # consumers parse them from text as a fallback.
    # Re-enable when vllm-mlx integrates both parsers in the streaming path.
    reasoningParser = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "qwen3"
          "deepseek_r1"
          "harmony"
        ]
      );
      default = null;
      description = "Reasoning content extraction parser. Disabled by default — conflicts with tool-call-parser in streaming mode (vllm-mlx bug).";
    };

    # mcpConfig — MCP configuration file (--mcp-config).
    # Path to JSON/YAML MCP config for server-side tool integration.
    # Disabled: MCP managed by consumers (Claude Code, PAL), not the inference server.
    # Revisit: if the inference server needs direct MCP tool access.
    # mcpConfig = lib.mkOption {
    #   type = lib.types.nullOr lib.types.path;
    #   default = null;
    #   description = "Path to MCP configuration file (JSON/YAML) for server-side tools.";
    # };

    # ---- EMBEDDINGS ----

    # embeddingModel — Pre-load embedding model at startup (--embedding-model).
    # Disabled: embeddings handled by separate services.
    # Revisit: if consolidating embedding generation into vllm-mlx.
    # embeddingModel = lib.mkOption {
    #   type = lib.types.nullOr lib.types.str;
    #   default = null;
    #   description = "HuggingFace ID of embedding model to pre-load at startup.";
    # };

    # ---- SECURITY ----

    # apiKey — API authentication key (--api-key).
    # Disabled: server binds to 127.0.0.1, no external access.
    # Revisit: if exposing the server on a network interface.
    # apiKey = lib.mkOption {
    #   type = lib.types.nullOr lib.types.str;
    #   default = null;
    #   description = "API authentication key. Not needed when binding to localhost.";
    # };

    # rateLimit — Requests per minute per client (--rate-limit).
    # Server default: 0 (disabled). Per-client rate limiting.
    # Disabled: single-user, localhost-only, no abuse vector.
    # Revisit: if exposing the server externally.
    # rateLimit = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.unsigned;
    #   default = null;
    #   description = "Requests per minute per client. 0 = disabled. Server default: 0.";
    # };

    # ---- LEGACY (not recommended) ----

    # prefixCacheSize — Max entries in prefix cache (--prefix-cache-size).
    # Server default: 100. LEGACY MODE ONLY — requires --no-memory-aware-cache.
    # Memory-aware mode (default) is strictly better: auto-sizes based on RAM.
    # Disabled: memory-aware mode handles this automatically.
    # Revisit: only if debugging memory-aware cache issues.
    # prefixCacheSize = lib.mkOption {
    #   type = lib.types.nullOr lib.types.ints.positive;
    #   default = null;
    #   description = "Legacy prefix cache entry count. Requires noMemoryAwareCache. Server default: 100.";
    # };

    # noMemoryAwareCache — Disable memory-aware cache (--no-memory-aware-cache).
    # Server default: memory-aware enabled. Falls back to legacy entry-count mode.
    # Disabled: memory-aware mode is strictly better.
    # Revisit: only if debugging memory-aware cache issues.
    # noMemoryAwareCache = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    #   description = "Disable memory-aware cache, use legacy entry-count mode. Not recommended.";
    # };

    # disablePrefixCache — Disable prefix caching entirely (--disable-prefix-cache).
    # Server default: prefix caching enabled. Disabling removes all prefix reuse.
    # Disabled: prefix caching provides significant TTFT speedup for repeated prompts.
    # Revisit: only if debugging prefix cache issues.
    # disablePrefixCache = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    #   description = "Disable prefix caching entirely. Not recommended.";
    # };

    # ---- OOM PREVENTION (2026-03-21 incident: 171.9 GB on 128 GB RAM) ----
    # ProcessType=Background makes vllm-mlx Jetsam-eligible; HardResourceLimits
    # sets a kernel-enforced RSS ceiling. KeepAlive auto-restarts after Jetsam kill.

    memoryHardLimitGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Hard RSS limit in GB. Kernel kills process above this. Leaves 28GB for OS + apps on 128GB systems.";
    };

    # ---- MODEL SWITCHING (llama-swap proxy) ----
    # llama-swap sits on the API port and manages vllm-mlx backends as child processes.
    # Model switching is transparent: send a request with model: "X" and the proxy handles it.

    models = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Additional vllm-mlx serve arguments for this model";
            };
            ttl = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 0;
              description = "Seconds of idle time before unloading. 0 = use proxy.idleTtl default.";
            };
            aliases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Alternative model names that route to this model";
            };
          };
        }
      );
      default = { };
      description = "Additional models available for on-demand switching via llama-swap proxy. The defaultModel is always available with TTL 0.";
    };

    proxy = {
      healthCheckTimeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 180;
        description = "Seconds to wait for a backend to become healthy. 70GB models take 20-60s to load; 180s covers the worst case.";
      };
      idleTtl = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1800;
        description = "Default idle TTL in seconds for non-default models. 0 = never auto-unload. Default 30 min.";
      };
      logLevel = lib.mkOption {
        type = lib.types.enum [
          "debug"
          "info"
          "warn"
          "error"
        ];
        default = "debug";
        description = ''
          llama-swap log verbosity. "debug" logs every proxied HTTP
          request/response body (prompts and completions), making
          `curl http://127.0.0.1:11434/logs/stream` a live I/O tap.
          Set to "info" to suppress request bodies and reduce log volume.
          Note: debug output rotates within the 10 MB LaunchAgent log limit.
        '';
      };
      logToStdout = lib.mkOption {
        type = lib.types.enum [
          "proxy"
          "upstream"
          "both"
          "none"
        ];
        default = "both";
        description = ''
          Which output streams llama-swap forwards to stdout (and therefore
          the /logs/stream SSE endpoint). "both" interleaves proxy request
          logs with vllm-mlx upstream output. "proxy" (default upstream
          behaviour) shows only proxy-level events.
        '';
      };
    };
  };
}
