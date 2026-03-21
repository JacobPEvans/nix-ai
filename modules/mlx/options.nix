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
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = "Default HuggingFace model to serve via vllm-mlx";
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
    # Benchmarked 2026-03-19 on M4 Max 128GB with Qwen3.5-122B-A10B-4bit.
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

    # reasoningParser — Reasoning content extraction (--reasoning-parser).
    # Options: qwen3, deepseek_r1, harmony.
    # Disabled: not needed for current API consumers.
    # Revisit: if using reasoning-aware consumers (e.g., qwen3 for our model).
    # reasoningParser = lib.mkOption {
    #   type = lib.types.nullOr (lib.types.enum [ "qwen3" "deepseek_r1" "harmony" ]);
    #   default = null;
    #   description = "Reasoning content extraction parser. Options: qwen3, deepseek_r1, harmony.";
    # };

    # enableAutoToolChoice — Auto tool choice for supported models (--enable-auto-tool-choice).
    # Server default: disabled.
    # Disabled: tool calling managed by consumers, not the server.
    # Revisit: if using native tool calling via the API.
    # enableAutoToolChoice = lib.mkOption {
    #   type = lib.types.bool;
    #   default = false;
    #   description = "Enable automatic tool choice for supported models.";
    # };

    # toolCallParser — Tool call parser (--tool-call-parser).
    # Options: auto, mistral, qwen, qwen3_coder, llama, hermes, deepseek, kimi,
    #          granite, nemotron, xlam, functionary, glm47.
    # Disabled: tool calling managed by consumers.
    # Revisit: if enabling enableAutoToolChoice.
    # toolCallParser = lib.mkOption {
    #   type = lib.types.nullOr (lib.types.enum [
    #     "auto" "mistral" "qwen" "qwen3_coder" "llama" "hermes"
    #     "deepseek" "kimi" "granite" "nemotron" "xlam" "functionary" "glm47"
    #   ]);
    #   default = null;
    #   description = "Tool call parser. Only used with enableAutoToolChoice.";
    # };

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

    # ---- OOM PREVENTION (2026-03-21 incident: Jetsam fired 3x, killed nothing) ----
    # Three python3.13 processes consumed 171.9 GB against 128 GB RAM.
    # Root cause: no ProcessType set, so Jetsam couldn't determine kill priority.

    memoryLimitGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Soft RSS limit in GB for vllm-mlx LaunchAgent. Process becomes Jetsam-eligible above this threshold.";
    };

    memoryHardLimitGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Hard RSS limit in GB. Kernel kills process above this. Leaves 28GB for OS + apps on 128GB systems.";
    };

    safetyOverheadGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
      description = "GB reserved for OS + other apps during pre-flight memory checks.";
    };
  };
}
