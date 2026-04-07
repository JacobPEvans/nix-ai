# PAL MCP — Model Configuration & Dynamic MLX Discovery
#
# Overrides PAL's bundled model configs with curated, Nix-managed JSON files
# so we control exactly which models are available — no dependency on PAL
# upstream release cadence.
#
# Provider configs (Gemini, OpenAI, OpenRouter) are defined in pal-model-defs.nix
# and serialized to JSON at eval time. Custom/local models are generated statically
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

  # Curated provider model definitions — split across two files to stay under
  # the 12KB file size limit. Update pal-model-defs*.nix when new models release.
  modelDefs = import ./pal-model-defs.nix;
  openrouterDefs = import ./pal-model-defs-openrouter.nix;

  # Generate JSON files in the Nix store
  geminiConfigFile = pkgs.writeText "pal-gemini-models.json" (builtins.toJSON modelDefs.gemini);
  openaiConfigFile = pkgs.writeText "pal-openai-models.json" (builtins.toJSON modelDefs.openai);
  openrouterConfigFile = pkgs.writeText "pal-openrouter-models.json" (builtins.toJSON openrouterDefs);

  # All configured MLX model names (default + on-demand) for PAL discovery.
  # Generated statically from Nix config — no runtime MLX server query needed.
  allMlxModelNames = lib.unique ([ mlxCfg.defaultModel ] ++ builtins.attrNames mlxCfg.models);
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

  # Writable path for custom models — allows sync-mlx-models CLI to update between rebuilds.
  # Activation seeds this from the static Nix store file; PAL reads from here at runtime.
  customModelsDir = "${config.home.homeDirectory}/.config/pal-mcp";
  customModelsPath = "${customModelsDir}/custom_models.json";
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
          runtimeEnv = {
            MLX_URL = "http://${mlxCfg.host}:${toString mlxCfg.port}/v1/models";
          };
          text = builtins.readFile ../mcp/scripts/sync-mlx-models-cli.sh;
        })
      ];

      activation = {
        # Create dirs and seed custom_models.json from the Nix-generated static file.
        palDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD bash -c '(umask 077 && mkdir -p "${palLogDir}" "${customModelsDir}")'
          $DRY_RUN_CMD cp -f "${customModelsConfigFile}" "${customModelsPath}"
        '';

        # Non-blocking health check — surfaces PAL issues early.
        # Skipped on dry-run to avoid Doppler network calls.
        palHealthCheck = lib.hm.dag.entryAfter [ "writeBoundary" "palDirs" ] ''
          if [ -z "''${DRY_RUN_CMD:-}" ]; then
            DOPPLER="${pkgs.doppler}/bin/doppler" \
            PAL_MCP_BIN="${palPkg}/bin/pal-mcp-server" \
            PAL_LOG_DIR="${palLogDir}" \
            . ${../mcp/scripts/check-pal-health.sh}
          fi
        '';
      };
    };

    # Inject env vars into PAL server.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    # Provider config overrides replace PAL's bundled conf/*.json with our curated lists.
    programs.claude.mcpServers.pal.env = {
      # Custom/local models (MLX) — writable path seeded from Nix at activation,
      # refreshable via sync-mlx-models CLI between rebuilds
      CUSTOM_MODELS_CONFIG_PATH = customModelsPath;
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
