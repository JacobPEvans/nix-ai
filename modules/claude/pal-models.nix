# PAL MCP — Model Configuration & Dynamic MLX Discovery
#
# Overrides PAL's bundled model configs with curated, Nix-managed JSON files
# so we control exactly which models are available — no dependency on PAL
# upstream release cadence.
#
# Provider configs (Gemini, OpenAI, OpenRouter) are static Nix store paths
# generated at eval time. Custom/local models are also generated statically
# from the Nix-configured llama-swap models.
#
# PAL's CapabilityModelRegistry checks env var paths first, falls back to
# bundled conf/*.json. Our env vars take precedence.
#
# Refresh local models between rebuilds with: sync-mlx-models
{
  config,
  lib,
  pkgs,
  pal-mcp-server,
  ...
}:

let
  cfg = config.programs.claude;
  mlxCfg = config.programs.mlx;
  palLogDir = "${config.home.homeDirectory}/.local/state/pal-mcp";
  palPkg = pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; };

  # ================================================================
  # Curated provider model configs (LATEST ONLY)
  # ================================================================
  # These override PAL's bundled conf/*.json files via env vars.
  # Update these attrsets when new model versions are released.

  geminiModels = {
    models = [
      {
        model_name = "gemini-3.1-pro-preview";
        friendly_name = "Gemini 3.1 Pro Preview";
        aliases = [
          "pro"
          "gemini3"
          "gemini-pro"
          "gemini"
        ];
        intelligence_score = 18;
        description = "Flagship reasoning (1M context) — enhanced SWE, agentic reliability, efficient tokens";
        context_window = 1048576;
        max_output_tokens = 65536;
        max_thinking_tokens = 32768;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        allow_code_generation = true;
        max_image_size_mb = 32.0;
      }
      {
        model_name = "gemini-3-flash-preview";
        friendly_name = "Gemini 3 Flash Preview";
        aliases = [
          "flash"
          "flash3"
          "gemini-flash"
        ];
        intelligence_score = 14;
        description = "Fast frontier-class (1M context) — near-Pro reasoning at Flash speed and cost";
        context_window = 1048576;
        max_output_tokens = 65536;
        max_thinking_tokens = 24576;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
      }
    ];
  };

  openaiModels = {
    models = [
      {
        model_name = "gpt-5.2";
        friendly_name = "OpenAI (GPT-5.2)";
        aliases = [
          "gpt5.2"
          "gpt-5.2"
          "5.2"
        ];
        intelligence_score = 18;
        description = "GPT-5.2 (400K context, 128K output) — Flagship reasoning with configurable thinking and vision";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        default_reasoning_effort = "medium";
        allow_code_generation = true;
        temperature_constraint = "fixed";
      }
      {
        model_name = "gpt-5.2-pro";
        friendly_name = "OpenAI (GPT-5.2 Pro)";
        aliases = [
          "gpt5.2-pro"
          "gpt5.2pro"
          "gpt5pro"
          "gpt5-pro"
        ];
        intelligence_score = 18;
        description = "GPT-5.2 Pro (400K context, 272K output) — Premium reasoning, highest quality responses";
        context_window = 400000;
        max_output_tokens = 272000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = false;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        use_openai_response_api = true;
        default_reasoning_effort = "high";
        allow_code_generation = true;
        temperature_constraint = "fixed";
      }
      {
        model_name = "gpt-5.1-codex";
        friendly_name = "OpenAI (GPT-5.1 Codex)";
        aliases = [
          "gpt5.1-codex"
          "codex"
          "gpt-5.1-code"
          "codex-5.1"
        ];
        intelligence_score = 19;
        description = "GPT-5.1 Codex (400K context, 128K output) — Agentic coding via Responses API";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = false;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        use_openai_response_api = true;
        default_reasoning_effort = "high";
        allow_code_generation = true;
        temperature_constraint = "fixed";
      }
      {
        model_name = "gpt-5.1-codex-mini";
        friendly_name = "OpenAI (GPT-5.1 Codex mini)";
        aliases = [
          "gpt5.1-codex-mini"
          "codex-mini"
          "5.1-codex-mini"
        ];
        intelligence_score = 16;
        description = "GPT-5.1 Codex mini (400K context, 128K output) — Cost-efficient coding with streaming";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        allow_code_generation = true;
        temperature_constraint = "fixed";
      }
      {
        model_name = "gpt-5-codex";
        friendly_name = "OpenAI (GPT-5 Codex)";
        aliases = [
          "gpt5-codex"
          "gpt-5-code"
          "gpt5-code"
        ];
        intelligence_score = 17;
        description = "GPT-5 Codex (400K context) — Coding, refactoring, and software architecture";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        use_openai_response_api = true;
      }
      {
        model_name = "gpt-5";
        friendly_name = "OpenAI (GPT-5)";
        aliases = [
          "gpt5"
        ];
        intelligence_score = 16;
        description = "GPT-5 (400K context, 128K output) — Advanced model with reasoning support";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = false;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        temperature_constraint = "fixed";
      }
      {
        model_name = "gpt-5-mini";
        friendly_name = "OpenAI (GPT-5-mini)";
        aliases = [
          "gpt5-mini"
          "gpt5mini"
          "mini"
        ];
        intelligence_score = 15;
        description = "GPT-5-mini (400K context, 128K output) — Efficient variant with reasoning support";
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_system_prompts = true;
        supports_streaming = false;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = true;
        max_image_size_mb = 20.0;
        temperature_constraint = "fixed";
      }
      {
        model_name = "o4-mini";
        friendly_name = "OpenAI (O4-mini)";
        aliases = [
          "o4mini"
        ];
        intelligence_score = 11;
        description = "O4-mini (200K context) — Fast reasoning, optimized for shorter contexts";
        context_window = 200000;
        supports_extended_thinking = false;
        supports_system_prompts = true;
        supports_streaming = true;
        supports_function_calling = true;
        supports_json_mode = true;
        supports_images = true;
        supports_temperature = false;
        max_image_size_mb = 20.0;
        temperature_constraint = "fixed";
      }
    ];
  };

  openrouterModels = {
    models = [
      # Anthropic — latest only
      {
        model_name = "anthropic/claude-opus-4.6";
        aliases = [
          "opus"
          "opus4.6"
          "claude-opus"
        ];
        context_window = 1000000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_json_mode = false;
        supports_function_calling = false;
        supports_images = true;
        max_image_size_mb = 5.0;
        description = "Claude Opus 4.6 — Anthropic's strongest model for coding and long-running tasks";
        intelligence_score = 19;
      }
      {
        model_name = "anthropic/claude-sonnet-4.6";
        aliases = [
          "sonnet"
          "sonnet4.6"
        ];
        context_window = 1000000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_json_mode = false;
        supports_function_calling = false;
        supports_images = true;
        max_image_size_mb = 5.0;
        description = "Claude Sonnet 4.6 — Frontier performance across coding, agents, and professional work";
        intelligence_score = 15;
      }

      # Google — latest only
      {
        model_name = "google/gemini-3.1-pro-preview";
        aliases = [
          "gemini-pro"
          "gemini3"
          "pro-openrouter"
        ];
        context_window = 1048576;
        max_output_tokens = 65536;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        allow_code_generation = true;
        description = "Gemini 3.1 Pro Preview via OpenRouter — flagship reasoning with vision";
        intelligence_score = 18;
      }
      {
        model_name = "google/gemini-3-flash-preview";
        aliases = [
          "flash-openrouter"
          "gemini-flash-openrouter"
        ];
        context_window = 1048576;
        max_output_tokens = 65536;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 15.0;
        description = "Gemini 3 Flash Preview via OpenRouter — near-Pro reasoning at Flash cost";
        intelligence_score = 14;
      }

      # OpenAI — latest only
      {
        model_name = "openai/gpt-5.2";
        aliases = [
          "gpt5.2-openrouter"
        ];
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = true;
        temperature_constraint = "fixed";
        default_reasoning_effort = "medium";
        allow_code_generation = true;
        description = "GPT-5.2 via OpenRouter — flagship reasoning with vision";
        intelligence_score = 18;
      }
      {
        model_name = "openai/gpt-5.2-pro";
        aliases = [
          "gpt5.2-pro-openrouter"
        ];
        context_window = 400000;
        max_output_tokens = 272000;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = false;
        temperature_constraint = "fixed";
        use_openai_response_api = true;
        default_reasoning_effort = "high";
        allow_code_generation = true;
        description = "GPT-5.2 Pro via OpenRouter — premium reasoning";
        intelligence_score = 18;
      }
      {
        model_name = "openai/gpt-5.1-codex";
        aliases = [
          "codex-openrouter"
        ];
        context_window = 400000;
        max_output_tokens = 128000;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = true;
        temperature_constraint = "fixed";
        use_openai_response_api = true;
        default_reasoning_effort = "high";
        allow_code_generation = true;
        description = "GPT-5.1 Codex via OpenRouter — agentic coding";
        intelligence_score = 19;
      }
      {
        model_name = "openai/o4-mini";
        aliases = [
          "o4-mini-openrouter"
          "o4mini-openrouter"
        ];
        context_window = 200000;
        max_output_tokens = 100000;
        supports_extended_thinking = false;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = false;
        temperature_constraint = "fixed";
        description = "O4-mini via OpenRouter — fast reasoning with vision";
        intelligence_score = 11;
      }

      # DeepSeek
      {
        model_name = "deepseek/deepseek-r1-0528";
        aliases = [
          "deepseek-r1"
          "deepseek"
          "r1"
        ];
        context_window = 65536;
        max_output_tokens = 32768;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = false;
        supports_images = false;
        max_image_size_mb = 0.0;
        description = "DeepSeek R1 with thinking mode — advanced reasoning (text-only)";
        intelligence_score = 15;
      }

      # X.AI — latest only
      {
        model_name = "x-ai/grok-4";
        aliases = [
          "grok-4"
          "grok4"
          "grok"
        ];
        context_window = 256000;
        max_output_tokens = 256000;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = true;
        temperature_constraint = "range";
        description = "Grok 4 via OpenRouter — vision and advanced reasoning";
        intelligence_score = 15;
      }
      {
        model_name = "x-ai/grok-4.1-fast";
        aliases = [
          "grok-4.1-fast"
          "grok-fast"
        ];
        context_window = 2000000;
        max_output_tokens = 2000000;
        supports_extended_thinking = true;
        supports_json_mode = true;
        supports_function_calling = true;
        supports_images = true;
        max_image_size_mb = 20.0;
        supports_temperature = true;
        temperature_constraint = "range";
        description = "Grok 4.1 Fast via OpenRouter (2M context) — fast reasoning with vision";
        intelligence_score = 15;
      }
    ];
  };

  # Generate JSON files in the Nix store
  geminiConfigFile = pkgs.writeText "pal-gemini-models.json" (builtins.toJSON geminiModels);
  openaiConfigFile = pkgs.writeText "pal-openai-models.json" (builtins.toJSON openaiModels);
  openrouterConfigFile = pkgs.writeText "pal-openrouter-models.json" (
    builtins.toJSON openrouterModels
  );

  # All configured MLX model names (default + on-demand) for PAL discovery.
  # Generated statically from Nix config — no runtime MLX server query needed.
  allMlxModelNames = [ mlxCfg.defaultModel ] ++ builtins.attrNames mlxCfg.models;
  customModels = {
    models = builtins.map (
      id:
      let
        parts = lib.splitString "/" id;
        short = lib.last parts;
        clean = builtins.replaceStrings [ "-4bit" "-8bit" "-3bit" ] [ "" "" "" ] (lib.toLower short);
        modelCfg = mlxCfg.models.${id} or null;
        configAliases = if modelCfg != null then modelCfg.aliases else [ ];
        allAliases = lib.unique (
          [
            short
            clean
          ]
          ++ configAliases
        );
      in
      {
        model_name = id;
        aliases = allAliases;
        intelligence_score = 17;
        speed_score = 12;
        json_mode = false;
        function_calling = true;
        images = false;
      }
    ) allMlxModelNames;
  };
  customModelsConfigFile = pkgs.writeText "pal-custom-models.json" (builtins.toJSON customModels);
in
{
  config = lib.mkIf cfg.enable {
    home = {
      # Install pal-mcp-server as a Nix package so `doppler-mcp pal-mcp-server`
      # resolves via PATH. The package is built from the pinned flake input.
      packages = [
        palPkg

        # Refresh custom_models.json between darwin-rebuild switches.
        # Queries MLX /v1/models for live models. Normally the static Nix-generated
        # config covers all configured models, but this is useful after downloading
        # a new model without a rebuild.
        (pkgs.writeShellApplication {
          name = "sync-mlx-models";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
          ];
          text = builtins.readFile ../mcp/scripts/sync-mlx-models-cli.sh;
        })
      ];

      activation = {
        # Ensure PAL log directory exists.
        palDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD bash -c '(umask 077 && mkdir -p "${palLogDir}")'
        '';

        # Non-blocking health check — surfaces PAL issues early.
        palHealthCheck = lib.hm.dag.entryAfter [ "writeBoundary" "palDirs" ] ''
          DOPPLER="${pkgs.doppler}/bin/doppler" \
          PAL_MCP_BIN="${palPkg}/bin/pal-mcp-server" \
          PAL_LOG_DIR="${palLogDir}" \
          . ${../mcp/scripts/check-pal-health.sh}
        '';
      };
    };

    # Inject env vars into PAL server.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    # Provider config overrides replace PAL's bundled conf/*.json with our curated lists.
    programs.claude.mcpServers.pal.env = {
      # Custom/local models (MLX) — static, generated from Nix mlx.models config
      CUSTOM_MODELS_CONFIG_PATH = "${customModelsConfigFile}";
      # Provider model configs — static, curated Nix store paths
      GEMINI_MODELS_CONFIG_PATH = "${geminiConfigFile}";
      OPENAI_MODELS_CONFIG_PATH = "${openaiConfigFile}";
      OPENROUTER_MODELS_CONFIG_PATH = "${openrouterConfigFile}";
      # Point PAL logs to a writable location (default tries to write inside the
      # read-only Nix store, producing "Permission denied: logs/" warnings).
      PAL_LOG_DIR = palLogDir;
    };
  };
}
