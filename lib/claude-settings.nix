# Pure Claude Code Settings Generator
#
# Generates the settings attrset without any derivations or platform-specific code.
# Used by:
#   - modules/home-manager/ai-cli/claude.nix (for deployment with jq pretty-printing)
#   - flake.nix CI output (for cross-platform schema validation)
#
# This separation enables pure Nix evaluation for CI while keeping
# pretty-printed JSON for local deployment.
#
# NOTE: Uses toClaudeMarketplaceFormat from lib/claude-registry.nix as
# SINGLE SOURCE OF TRUTH for marketplace format transformation.

# NOTE: lib MUST be passed in explicitly - no default value.
# This ensures pure evaluation (CI) works correctly without <nixpkgs> lookup.
{
  lib,
  homeDir,
  schemaUrl,
  permissions, # { allow, deny, ask }
  plugins, # { marketplaces, enabledPlugins }
}:

let
  # Import the single source of truth for marketplace formatting
  claudeRegistry = import ./claude-registry.nix { inherit lib; };
  inherit (claudeRegistry) toClaudeMarketplaceFormat;
in
{
  # JSON Schema for IDE IntelliSense and validation
  "$schema" = schemaUrl;

  # Enable extended thinking mode
  alwaysThinkingEnabled = true;

  # Plugin marketplace configuration - transformed to Claude's expected format
  extraKnownMarketplaces = lib.mapAttrs toClaudeMarketplaceFormat plugins.marketplaces;

  # Enabled plugins from marketplaces
  inherit (plugins) enabledPlugins;

  # Permissions from ai-assistant-instructions
  permissions = {
    inherit (permissions) allow deny ask;

    # Directory-level read access
    additionalDirectories = [
      "~/" # Full home directory access
      "~/.claude/" # Claude configuration
      "~/.config/" # XDG config directory
    ];
  };

  # Status line configuration
  statusLine = {
    type = "command";
    command = "${homeDir}/.claude/statusline-command.sh";
  };

  # NOTE: MCP servers are NOT configured in settings.json
  # Claude Code reads MCP servers from ~/.claude.json (user scope) or .mcp.json (project scope)
  # Use `claude mcp add --scope user` to add servers declaratively
  # Available servers: pal, github, terraform (add via CLI as needed)
}
