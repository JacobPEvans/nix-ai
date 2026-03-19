# PAL MCP — Dynamic MLX + Static Ollama Model Discovery
#
# Generates ~/.config/pal-mcp/custom_models.json by combining:
#   1. Dynamic MLX models from vllm-mlx /v1/models (OpenAI-compatible)
#   2. Dynamic Ollama models from /api/tags (via pal-models.jq, if reachable)
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
in
{
  config = lib.mkIf cfg.enable {
    # Install pal-mcp-server as a Nix package so `doppler-mcp pal-mcp-server`
    # resolves via PATH. The package is built from the pinned flake input.
    home.packages = [
      (pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; })

      # Refresh custom_models.json between darwin-rebuild switches.
      # Queries MLX /v1/models (primary) and Ollama /api/tags (fallback).
      (pkgs.writeShellScriptBin "sync-mlx-models" ''
        set -euo pipefail
        mkdir -p "${outputDir}"

        # Query MLX vllm-mlx for loaded models (OpenAI format)
        mlx_json=$(${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString mlxCfg.port}/v1/models \
          | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models-mlx.jq} 2>/dev/null \
          || echo '{"models": []}')

        # Query Ollama for any additional local models (if reachable)
        ollama_json=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
          | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models.jq} 2>/dev/null \
          || echo '{"models": []}')

        # Merge MLX + Ollama models
        echo "$mlx_json" \
          | ${pkgs.jq}/bin/jq --argjson ollama "$(echo "$ollama_json" | ${pkgs.jq}/bin/jq '.models')" \
            '.models += $ollama' \
          > "${outputFile}"
        echo "PAL custom models updated. Restart Claude Code to pick up changes."
      '')
    ];

    # Inject CUSTOM_MODELS_CONFIG_PATH into PAL server env.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    programs.claude.mcpServers.pal.env.CUSTOM_MODELS_CONFIG_PATH = outputFile;

    # Generate custom_models.json by merging dynamic MLX + Ollama models.
    # If either server is unreachable, its section contributes an empty list.
    home.activation.palCustomModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${outputDir}"

      # Query MLX vllm-mlx for loaded models (OpenAI format)
      mlx_json=$(${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString mlxCfg.port}/v1/models \
        | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models-mlx.jq} 2>/dev/null \
        || echo '{"models": []}')

      # Query Ollama for any additional local models (if reachable)
      ollama_json=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
        | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models.jq} 2>/dev/null \
        || echo '{"models": []}')

      # Merge MLX + Ollama models
      echo "$mlx_json" \
        | ${pkgs.jq}/bin/jq --argjson ollama "$(echo "$ollama_json" | ${pkgs.jq}/bin/jq '.models')" \
          '.models += $ollama' \
        > "${outputFile}"
    '';
  };
}
