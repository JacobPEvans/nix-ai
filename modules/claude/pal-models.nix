# PAL MCP — Dynamic Model Discovery
#
# Generates PAL model configs from runtime API queries:
#   - custom_models.json     — from MLX vllm-mlx /v1/models (local)
#   - openrouter_models.json — from OpenRouter public API (no auth)
#
# All cloud models route through OpenRouter — single source of truth.
# Models are filtered by recency (last 90 days) and scored by price.
# PAL's bundled native provider configs (Gemini/OpenAI/xAI) remain stale
# but unused — OpenRouter handles all cloud routing.
#
# Configs rebuild at activation time (darwin-rebuild switch) and can be
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

  # Scripts directory holds pal-models-shared.jq, used by jq -L for `include`.
  scriptsDir = ../mcp/scripts;

  # Common env shared by all sync scripts
  commonSyncEnv = ''
    export CURL="${pkgs.curl}/bin/curl"
    export JQ="${pkgs.jq}/bin/jq"
    export OUTPUT_DIR="${outputDir}"
    export SCRIPTS_DIR="${scriptsDir}"
  '';

  # MLX-specific sync env (used by both CLI tool and activation)
  mlxSyncEnv = ''
    ${commonSyncEnv}
    export MLX_JQ_FILE="${scriptsDir}/pal-models-mlx.jq"
    export MLX_URL="http://${mlxCfg.host}:${toString mlxCfg.port}/v1/models"
    export OUTPUT_FILE="${outputFile}"
  '';

  # Cloud-specific sync env (OpenRouter public API, no auth)
  cloudSyncEnv = ''
    ${commonSyncEnv}
    export OPENROUTER_JQ_FILE="${scriptsDir}/pal-models-openrouter.jq"
  '';
in
{
  config = lib.mkMerge [
    {
      # Install palPkg and pal-mcp wrapper unconditionally — needed by Codex and
      # Gemini MCP config (mcp/default.nix: `command = "pal-mcp"`) even when
      # programs.claude.enable = false. Previously only doppler-mcp was unconditional;
      # moving to the wrapper pattern must preserve that availability.
      home.packages = [
        palPkg

        # pal-mcp — PAL MCP launcher with all env vars baked in.
        # Env vars survive Claude Code's ~/.claude.json rewrites (JacobPEvans/nix-ai#557).
        # Dynamic paths (Nix-interpolated) + static config inline — no separate .sh file.
        (pkgs.writeShellApplication {
          name = "pal-mcp";
          runtimeInputs = [ ];
          text = ''
            # Dynamic config (Nix-interpolated at build time)
            export CUSTOM_MODELS_CONFIG_PATH="${outputFile}"
            export CUSTOM_MODEL_NAME="${mlxCfg.defaultModel}"
            export OPENROUTER_MODELS_CONFIG_PATH="${outputDir}/openrouter_models.json"
            export PAL_LOG_DIR="${palLogDir}"

            # Static PAL config — enabled tools: chat, listmodels, clink, consensus
            export DISABLED_TOOLS="thinkdeep,planner,codereview,precommit,debug,analyze,tracer,refactor,testgen,secaudit,docgen,apilookup,challenge,version"
            export DEFAULT_MODEL="auto"
            export CUSTOM_API_URL="http://localhost:30080/v1"
            export CUSTOM_CONNECT_TIMEOUT="30"
            export CUSTOM_READ_TIMEOUT="300"
            export CONVERSATION_TIMEOUT_HOURS="6"
            export MAX_CONVERSATION_TURNS="50"
            export LOG_LEVEL="INFO"

            exec doppler-mcp "${palPkg}/bin/pal-mcp-server" "$@"
          '';
        })
      ];
    }

    (lib.mkIf cfg.enable {
      home = {
        packages = [
          # Refresh custom_models.json between darwin-rebuild switches.
          # Queries MLX /v1/models for available models.
          (pkgs.writeShellScriptBin "sync-mlx-models" ''
            set -euo pipefail
            ${mlxSyncEnv}
            . ${../mcp/scripts/sync-pal-models.sh}
            echo "PAL custom models updated. Restart Claude Code to pick up changes."
          '')

          # Refresh cloud model config between darwin-rebuild switches.
          # Queries OpenRouter public API (no auth) — single source of truth for all cloud models.
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
          # Skipped on dry-run because the sync script makes external network calls.
          palCloudModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${cloudSyncEnv}
            if [ -z "''${DRY_RUN_CMD:-}" ]; then
              . ${../mcp/scripts/sync-pal-cloud-models.sh}
            fi
          '';

          # Non-blocking health check — runs after activation to surface PAL issues
          # early (Doppler auth, missing secrets). Never blocks activation (always exits 0).
          # Skipped on dry-run (not prefixed with $DRY_RUN_CMD) because the check makes
          # network calls to Doppler that are inappropriate for a dry-run.
          palHealthCheck = lib.hm.dag.entryAfter [ "writeBoundary" "palCustomModels" "palCloudModels" ] ''
            if [ -z "''${DRY_RUN_CMD:-}" ]; then
              export DOPPLER="${pkgs.doppler}/bin/doppler" PAL_MCP_BIN="${palPkg}/bin/pal-mcp-server" PAL_LOG_DIR="${palLogDir}"
              . ${../mcp/scripts/check-pal-health.sh}
            fi
          '';
        };
      };

      # PAL MCP server is now launched via the pal-mcp wrapper (above).
      # All env vars are baked into the wrapper — no env block needed here.
      programs.claude.mcpServers.pal.command = "pal-mcp";
    })
  ];
}
