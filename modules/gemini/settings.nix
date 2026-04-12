# Gemini Settings Generation
#
# Generates settings.json and manages the activation merge.
# settings.json is NOT a read-only symlink — Gemini writes auth tokens
# and runtime state to this file.
#
# CRITICAL - tools.allowed vs tools.core:
# Per the official Gemini CLI schema:
# - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
# - tools.core = "Allowlist to RESTRICT built-in tools to a specific set" (LIMITS usage!)
# Always use tools.allowed for auto-approval, NEVER tools.core!
{
  pkgs,
  config,
  lib,
  ai-assistant-instructions,
  ...
}:

let
  cfg = config.programs.gemini;
  homeDir = config.home.homeDirectory;

  aiCommon = import ../common {
    inherit lib config ai-assistant-instructions;
  };
  inherit (aiCommon) permissions formatters;

  defaultTrustedFolders = [
    "${homeDir}/.config/nix"
    "${homeDir}/git"
  ];

  # Normalize MCP server for Gemini format
  # stdio: { command, args?, env?, cwd?, timeout? }
  # HTTP/SSE: { httpUrl, headers? } (note: httpUrl not url)
  normalizeGeminiMcpServer =
    server:
    if server ? url then
      # HTTP/SSE server
      { httpUrl = server.url; } // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
    else
      # stdio server
      lib.filterAttrs (_name: value: value != null && value != [ ] && value != { }) (
        {
          command = server.command or null;
          args = server.args or [ ];
          env = server.env or { };
        }
        // lib.optionalAttrs (server ? cwd) { inherit (server) cwd; }
        // lib.optionalAttrs (server ? timeout) { inherit (server) timeout; }
      );

  mcpServers =
    let
      sharedServers = import ../mcp;
    in
    lib.mapAttrs' (name: server: lib.nameValuePair name (normalizeGeminiMcpServer server)) (
      lib.filterAttrs (
        name: server: !(server.disabled or false) && !(lib.elem name cfg.excludedMcpServers)
      ) sharedServers
    );

  settings = {
    "$schema" =
      "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json";

    general = {
      previewFeatures = true;
      disableAutoUpdate = true;
    };

    context = {
      fileName = [
        "AGENTS.md"
        "GEMINI.md"
      ];
    };

    security = {
      folderTrust = {
        enabled = true;
        trustedFolders = lib.unique (defaultTrustedFolders ++ cfg.trustedFolders);
      };
    };

    tools = {
      allowed = formatters.gemini.formatAllowedTools permissions;
      exclude = formatters.gemini.formatExcludeTools permissions;
      sandbox = true;
    };

    inherit mcpServers;
  };

  settingsJson =
    pkgs.runCommand "gemini-settings.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        json = builtins.toJSON settings;
        passAsFile = [ "json" ];
      }
      ''
        jq '.' "$jsonPath" > $out
      '';
in
{
  config = lib.mkIf cfg.enable {
    home.activation.mergeGeminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.jq}/bin:$PATH"
      $DRY_RUN_CMD ${../scripts/merge-json-settings.sh} \
        "${settingsJson}" \
        "${homeDir}/.gemini/settings.json"
    '';
  };
}
