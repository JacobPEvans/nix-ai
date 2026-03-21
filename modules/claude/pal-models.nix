# PAL MCP — Dynamic MLX Model Discovery
#
# Generates ~/.config/pal-mcp/custom_models.json from the MLX vllm-mlx
# /v1/models endpoint (OpenAI-compatible).
#
# The file is rebuilt at activation time (darwin-rebuild switch) and can be
# refreshed between rebuilds with: sync-mlx-models
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

  # Shared environment for the sync script (used by both CLI tool and activation)
  syncEnv = ''
    export CURL="${pkgs.curl}/bin/curl"
    export JQ="${pkgs.jq}/bin/jq"
    export MLX_JQ_FILE="${../mcp/scripts/pal-models-mlx.jq}"
    export MLX_URL="http://${mlxCfg.host}:${toString mlxCfg.port}/v1/models"
    export OUTPUT_DIR="${outputDir}"
    export OUTPUT_FILE="${outputFile}"
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
          ${syncEnv}
          . ${../mcp/scripts/sync-pal-models.sh}
          echo "PAL custom models updated. Restart Claude Code to pick up changes."
        '')
      ];

      activation = {
        # Generate custom_models.json from dynamic MLX models.
        # If the server is unreachable, the previous file is preserved.
        palCustomModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${syncEnv}
          $DRY_RUN_CMD bash -c '(umask 077 && mkdir -p "${palLogDir}")'
          . ${../mcp/scripts/sync-pal-models.sh}
        '';

        # Non-blocking health check — runs after activation to surface PAL issues
        # early (Doppler auth, missing secrets). Never blocks activation (always exits 0).
        # Skipped on dry-run (not prefixed with $DRY_RUN_CMD) because the check makes
        # network calls to Doppler that are inappropriate for a dry-run.
        palHealthCheck = lib.hm.dag.entryAfter [ "writeBoundary" "palCustomModels" ] ''
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
      # Point PAL logs to a writable location (default tries to write inside the
      # read-only Nix store, producing "Permission denied: logs/" warnings).
      PAL_LOG_DIR = palLogDir;
    };
  };
}
