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
# Version pinning:
#   The PAL server args use a pinned git commit hash (from flake.lock) instead
#   of the Nix store path. The Nix store path approach fails because setuptools_scm
#   tries to write egg-info to the read-only Nix store during uvx build.
#   To update: run `nix flake update pal-mcp-server` and update the rev in args.
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
    # Pin PAL to the flake-locked git commit via git URL.
    # NOTE: Using the Nix store path directly (${pal-mcp-server}) does NOT work —
    # setuptools_scm tries to write pal_mcp_server.egg-info to the source directory
    # during uvx build, which fails because the Nix store is read-only.
    # The git URL approach lets uvx clone to a writable temp dir, and the commit
    # hash provides the same pinning guarantee as the Nix store path.
    # The rev comes from flake.lock (nodes.pal-mcp-server.locked.rev).
    programs.claude.mcpServers.pal.args = lib.mkForce [
      "uvx"
      "--from"
      "git+https://github.com/BeehiveInnovations/pal-mcp-server.git@7afc7c1cc96e23992c8f105f960132c657883bb1"
      "pal-mcp-server"
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
