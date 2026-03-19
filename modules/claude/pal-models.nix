# PAL MCP — Dynamic Ollama + Static MLX Model Discovery
#
# Generates ~/.config/pal-mcp/custom_models.json by combining:
#   1. Dynamic Ollama models from /api/tags (via pal-models.jq)
#   2. Static MLX model entry for the vllm-mlx inference server
#
# The file is rebuilt at activation time (darwin-rebuild switch) and can be
# refreshed between rebuilds with: sync-ollama-models
#
# The colon alias trick:
#   PAL's parse_model_option() strips ":tag" before registry lookup, so a
#   model like "glm-5:cloud" must be registered with alias "glm-5". When the
#   user asks for "glm-5", PAL finds the alias → resolves to "glm-5:cloud" →
#   sends that to Ollama. This is handled automatically by pal-models.jq.
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

  # Static MLX model entry — always present regardless of Ollama availability.
  # The model_name matches the HuggingFace ID used by vllm-mlx.
  mlxModelJson = builtins.toJSON {
    model_name = mlxCfg.defaultModel;
    aliases = [
      "gpt-oss"
      "gpt-oss-120b"
    ];
    intelligence_score = 17;
    speed_score = 8;
    json_mode = false;
    function_calling = false;
    images = false;
  };
in
{
  config = lib.mkIf cfg.enable {
    # Install pal-mcp-server as a Nix package so `doppler-mcp pal-mcp-server`
    # resolves via PATH. The package is built from the pinned flake input.
    home.packages = [
      (pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; })

      # Refresh custom_models.json between darwin-rebuild switches.
      # Run after `ollama pull <model>` to register new models in PAL.
      (pkgs.writeShellScriptBin "sync-ollama-models" ''
        set -euo pipefail
        mkdir -p "${outputDir}"

        # Try Ollama first; fall back to empty model list
        ollama_json=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
          | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models.jq} 2>/dev/null \
          || echo '{"models": []}')

        # Append static MLX model entry
        echo "$ollama_json" \
          | ${pkgs.jq}/bin/jq --argjson mlx '${mlxModelJson}' '.models += [$mlx]' \
          > "${outputFile}"
        echo "PAL custom models updated. Restart Claude Code to pick up changes."
      '')
    ];

    # Inject CUSTOM_MODELS_CONFIG_PATH into PAL server env.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    programs.claude.mcpServers.pal.env.CUSTOM_MODELS_CONFIG_PATH = outputFile;

    # Generate custom_models.json by merging dynamic Ollama models + static MLX model.
    # If Ollama is unreachable, the file contains only the MLX model entry.
    home.activation.palCustomModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${outputDir}"

      # Try Ollama first; fall back to empty model list
      ollama_json=$(${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
        | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models.jq} 2>/dev/null \
        || echo '{"models": []}')

      # Append static MLX model entry
      echo "$ollama_json" \
        | ${pkgs.jq}/bin/jq --argjson mlx '${mlxModelJson}' '.models += [$mlx]' \
        > "${outputFile}"
    '';
  };
}
