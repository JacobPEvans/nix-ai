# PAL MCP — Dynamic Model Discovery
#
# Generates PAL model configs from runtime API queries:
#   - custom_models.json   — from MLX vllm-mlx /v1/models (local)
#   - gemini_models.json   — from OpenRouter public API (no auth)
#   - openai_models.json   — from OpenRouter public API (no auth)
#   - openrouter_models.json — from OpenRouter public API (no auth)
#
# All configs are rebuilt at activation time (darwin-rebuild switch) and can be
# refreshed between rebuilds with: sync-mlx-models / sync-pal-cloud-models
#
# PAL is built as a Nix derivation (modules/mcp/pal-package.nix) and installed
# via home.packages. This eliminates the uvx git-clone approach that previously
# failed with Permission denied when setuptools_scm tried to write to the
# read-only Nix store.
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
  outputDir = "${config.home.homeDirectory}/.config/pal-mcp";
  outputFile = "${outputDir}/custom_models.json";
  palLogDir = "${config.home.homeDirectory}/.local/state/pal-mcp";
  palPkg = pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; };

  # Common env shared by both MLX and cloud sync scripts
  commonSyncEnv = ''
    export CURL="${pkgs.curl}/bin/curl"
    export JQ="${pkgs.jq}/bin/jq"
    export OUTPUT_DIR="${outputDir}"
  '';

  # MLX-specific sync env (used by both CLI tool and activation)
  mlxSyncEnv = ''
    ${commonSyncEnv}
    export MLX_JQ_FILE="${../mcp/scripts/pal-models-mlx.jq}"
    export MLX_URL="http://${mlxCfg.host}:${toString mlxCfg.port}/v1/models"
    export OUTPUT_FILE="${outputFile}"
  '';

  # Cloud-specific sync env (OpenRouter public API, no auth)
  cloudSyncEnv = ''
    ${commonSyncEnv}
    export GEMINI_JQ_FILE="${../mcp/scripts/pal-models-gemini.jq}"
    export OPENAI_JQ_FILE="${../mcp/scripts/pal-models-openai.jq}"
    export OPENROUTER_JQ_FILE="${../mcp/scripts/pal-models-openrouter.jq}"
  '';
in
{
  config = lib.mkIf cfg.enable {
    home = {
      # Install pal-mcp-server as a Nix package so `doppler-mcp pal-mcp-server`
      # resolves via PATH. The package is built from the pinned flake input.
      packages = [
        palPkg

        # Refresh custom_models.json between darwin-rebuild switches.
        # Queries MLX /v1/models for available models.
        (pkgs.writeShellScriptBin "sync-mlx-models" ''
          set -euo pipefail
          ${mlxSyncEnv}
          . ${../mcp/scripts/sync-pal-models.sh}
          echo "PAL custom models updated. Restart Claude Code to pick up changes."
        '')

        # Refresh cloud model configs between darwin-rebuild switches.
        # Queries OpenRouter public API (no auth needed) for Gemini, OpenAI, OpenRouter models.
        (pkgs.writeShellScriptBin "sync-pal-cloud-models" ''
          set -euo pipefail
          ${cloudSyncEnv}
          . ${../mcp/scripts/sync-pal-cloud-models.sh}
          echo "PAL cloud models updated. Restart Claude Code to pick up changes."
        '')
      ];

      activation = {
        # Generate custom_models.json from dynamic MLX models.
        # If the server is unreachable, the previous file is preserved.
        palCustomModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${mlxSyncEnv}
          $DRY_RUN_CMD bash -c '(umask 077 && mkdir -p "${palLogDir}")'
          . ${../mcp/scripts/sync-pal-models.sh}
        '';

        # Generate cloud model configs from OpenRouter public API.
        # No auth required. Preserves previous files if API is unreachable.
        palCloudModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${cloudSyncEnv}
          . ${../mcp/scripts/sync-pal-cloud-models.sh}
        '';

        # Non-blocking health check — runs after activation to surface PAL issues
        # early (Doppler auth, missing secrets). Never blocks activation (always exits 0).
        # Skipped on dry-run (not prefixed with $DRY_RUN_CMD) because the check makes
        # network calls to Doppler that are inappropriate for a dry-run.
        palHealthCheck = lib.hm.dag.entryAfter [ "writeBoundary" "palCustomModels" "palCloudModels" ] ''
          if [ -z "''${DRY_RUN_CMD:-}" ]; then
            export DOPPLER="${pkgs.doppler}/bin/doppler"
            export PAL_MCP_BIN="${palPkg}/bin/pal-mcp-server"
            export PAL_LOG_DIR="${palLogDir}"
            . ${../mcp/scripts/check-pal-health.sh}
          fi
        '';
      };
    };

    # Inject env vars into PAL server.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    programs.claude.mcpServers.pal.env = {
      CUSTOM_MODELS_CONFIG_PATH = outputFile;
      # Override PAL's hardcoded llama3.2 default — dynamically tracks programs.mlx.defaultModel.
      CUSTOM_MODEL_NAME = mlxCfg.defaultModel;
      # Cloud model configs generated from OpenRouter public API at activation time.
      GEMINI_MODELS_CONFIG_PATH = "${outputDir}/gemini_models.json";
      OPENAI_MODELS_CONFIG_PATH = "${outputDir}/openai_models.json";
      OPENROUTER_MODELS_CONFIG_PATH = "${outputDir}/openrouter_models.json";
      # Point PAL logs to a writable location (default tries to write inside the
      # read-only Nix store, producing "Permission denied: logs/" warnings).
      PAL_LOG_DIR = palLogDir;
    };
  };
}
