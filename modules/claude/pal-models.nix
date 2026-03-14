# PAL MCP — Dynamic Ollama Model Discovery
#
# Generates ~/.config/pal-mcp/custom_models.json from the Ollama REST API at
# activation time (darwin-rebuild switch) and injects CUSTOM_MODELS_CONFIG_PATH
# into the PAL server env.
#
# Model registry is rebuilt on every rebuild and can be refreshed between
# rebuilds with: sync-ollama-models
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
  outputDir = "${config.home.homeDirectory}/.config/pal-mcp";
  outputFile = "${outputDir}/custom_models.json";
in
{
  config = lib.mkIf (cfg.enable && cfg.mcpServers ? pal && !(cfg.mcpServers.pal.disabled or false)) {
    # Install pal-mcp-server as a Nix package so `doppler-mcp pal-mcp-server`
    # resolves via PATH. The package is built from the pinned flake input.
    # Guarded: only install when the pal MCP server is present and not disabled.
    home.packages = [
      (pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; })
    ];

    # Inject CUSTOM_MODELS_CONFIG_PATH into PAL server env.
    # Merges with the env block defined in mcp/default.nix (DISABLED_TOOLS, etc.).
    programs.claude.mcpServers.pal.env.CUSTOM_MODELS_CONFIG_PATH = outputFile;

    # Generate custom_models.json from Ollama REST API during darwin-rebuild switch.
    # If Ollama is unreachable the existing file is kept and no error is raised.
    home.activation.palCustomModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${outputDir}"
      ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
        | ${pkgs.jq}/bin/jq --from-file ${../mcp/scripts/pal-models.jq} \
        > "${outputFile}" \
      || echo "pal-models: Ollama unreachable — keeping existing file" >&2
    '';
  };
}
