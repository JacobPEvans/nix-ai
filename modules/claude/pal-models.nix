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
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  outputDir = "${config.home.homeDirectory}/.config/pal-mcp";
  outputFile = "${outputDir}/custom_models.json";
in
{
  config = lib.mkIf cfg.enable {
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
