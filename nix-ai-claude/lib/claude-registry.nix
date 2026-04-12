# Claude Registry Functions
#
# Generates known_marketplaces.json structure that Claude Code expects.
#
# CRITICAL FIELDS (must match Claude's expectations exactly):
# ============================================================================
# 1. Marketplace Keys: MUST match the `name` field from the marketplace's
#    .claude-plugin/marketplace.json file (NOT the GitHub repo path)
#    Example: anthropics/skills → manifest name is "anthropic-agent-skills"
#
# 2. source.source: Always "github" for GitHub repos (lowercase)
# 3. source.repo: GitHub path "owner/repo" format
# 4. installLocation: Full absolute path to cache directory
# 5. lastUpdated: ISO 8601 timestamp with milliseconds
#
# How to find manifest names: See docs/TESTING-MARKETPLACES.md
# ============================================================================
#
# Parameters:
#   lib: nixpkgs lib (required)
#   lastUpdated: ISO 8601 timestamp (default: epoch, caller should provide current time)
{
  lib,
  lastUpdated ? "1970-01-01T00:00:00.000Z",
}:

let
  # ==========================================================================
  # SINGLE SOURCE OF TRUTH: Marketplace Format Transformation
  # ==========================================================================
  # This function converts Nix marketplace definitions into Claude Code format.
  #
  # INPUT SPECIFICATION (Nix definition):
  #   {
  #     source = {
  #       type = "github";           # or "git" for full URLs
  #       url = "owner/repo";        # GitHub short form: owner/repo
  #                                   # OR full URL: https://github.com/owner/repo.git
  #     };
  #   }
  #
  # OUTPUT SPECIFICATION (Claude Code settings.json):
  #   {
  #     source = {
  #       source = "github";         # Always "github" for GitHub repos
  #       repo = "marketplace-key";  # The marketplace identifier
  #     };
  #   }
  #
  # TRANSFORMATION LOGIC:
  #   - Both type="github" and type="git" become source="github" in output
  #   - The URL field becomes the repo value (the actual GitHub path for fetching)
  #   - The KEY can differ from URL for display purposes (e.g., "wakatime" vs "wakatime/claude-code-wakatime")
  #   - Non-GitHub types keep their source type and url unchanged
  #
  # DOCUMENTATION LOCATION:
  #   See modules/home-manager/ai-cli/claude-plugins.nix for detailed format docs
  #   and examples of correct usage.
  #
  # Usage: Import this function in any module that needs to transform marketplaces:
  #   claudeRegistry = import ../../lib/claude-registry.nix { inherit lib; };
  #   transformed = claudeRegistry.toClaudeMarketplaceFormat name marketplace;
  #
  toClaudeMarketplaceFormat = _name: m: {
    source =
      if m.source.type == "github" || m.source.type == "git" then
        {
          source = "github";
          repo = m.source.url; # Use URL for GitHub path (allows key to differ for display)
        }
      else
        {
          source = m.source.type;
          inherit (m.source) url;
        };
  };
in
{
  # Export the transformation function for use by other modules
  inherit toClaudeMarketplaceFormat;
  # Generate the full known_marketplaces.json structure
  # Matches native Claude Code format exactly
  mkKnownMarketplaces =
    {
      marketplaces,
      homeDir ? "/home/user",
      allowRuntimeInstall ? true,
    }:
    let
      # Extract marketplace name from the identifier
      # e.g., "anthropics/claude-plugins-official" -> "claude-plugins-official"
      #       "org/team/repo" -> "repo"
      getMarketplaceName = name: lib.last (lib.splitString "/" name);

      # Convert marketplace config to native format
      # Uses toClaudeMarketplaceFormat for consistent source formatting
      toNativeFormat =
        name: m:
        let
          marketplaceName = getMarketplaceName name;
          # Native format uses local paths, not Nix store
          localPath = "${homeDir}/.claude/plugins/marketplaces/${marketplaceName}";
          # Reuse single source of truth for marketplace format
          formatted = toClaudeMarketplaceFormat name m;
        in
        lib.nameValuePair marketplaceName {
          # Field order matches native: source, installLocation, lastUpdated
          inherit (formatted) source;
          installLocation = localPath;
          inherit lastUpdated;
        };
    in
    # NOTE: "local" marketplace removed - Claude Code doesn't create one by default.
    # See docs/CLAUDE-MARKETPLACE-ARCHITECTURE.md for details.
    lib.listToAttrs (lib.mapAttrsToList toNativeFormat marketplaces);

  # Generate installed_plugins.json structure
  mkInstalledPlugins =
    {
      schemaVersion ? 1,
    }:
    {
      version = schemaVersion;
      plugins = { };
    };

  # Generate settings.json structure (pure, no derivations)
  mkSettings =
    {
      schemaUrl ? "https://json.schemastore.org/claude-code-settings.json",
      alwaysThinkingEnabled ? true,
      permissions ? {
        allow = [ ];
        deny = [ ];
        ask = [ ];
      },
      additionalDirectories ? [ ],
      marketplaces ? { },
      enabledPlugins ? { },
      mcpServers ? { },
    }:
    {
      "$schema" = schemaUrl;
      inherit alwaysThinkingEnabled;
      permissions = {
        allow = permissions.allow or [ ];
        deny = permissions.deny or [ ];
        ask = permissions.ask or [ ];
      };
      inherit additionalDirectories;
      # Uses toClaudeMarketplaceFormat (single source of truth)
      extraKnownMarketplaces = lib.mapAttrs toClaudeMarketplaceFormat marketplaces;
      inherit enabledPlugins;
      mcpServers = lib.filterAttrs (_: s: !(s.disabled or false)) mcpServers;
    };
}
