# Claude Code Plugins - Main Configuration
#
# Modular plugin configuration organized by category:
# - marketplaces.nix: All available plugin marketplaces
# - official.nix: Official Anthropic plugins
# - external.nix: External third-party plugins (via claude-plugins-official)
# - community.nix: Community marketplace plugins
# - infrastructure.nix: Infrastructure, DevOps, and cloud operations
# - development.nix: Software development and engineering tools
# - monitoring.nix: Time tracking and monitoring tools
# - experimental.nix: Experimental and autonomous plugins
#
# Each module exports an enabledPlugins attrset that gets merged.
# The marketplaces module exports a marketplaces attrset.

{
  lib,
  marketplaceInputs,
  ...
}:

let
  # Extract specific inputs needed by sub-modules
  inherit (marketplaceInputs) jacobpevans-cc-plugins;

  # Import all plugin category modules
  marketplacesModule = import ./marketplaces.nix { inherit lib; };
  officialModule = import ./official.nix { };
  externalModule = import ./external.nix { };
  communityModule = import ./community.nix { };
  infrastructureModule = import ./infrastructure.nix { };
  developmentModule = import ./development.nix { inherit lib jacobpevans-cc-plugins; };
  monitoringModule = import ./monitoring.nix { };
  experimentalModule = import ./experimental.nix { };

  # Merge all enabled plugins from category modules
  enabledPlugins =
    officialModule.enabledPlugins
    // externalModule.enabledPlugins
    // communityModule.enabledPlugins
    // infrastructureModule.enabledPlugins
    // developmentModule.enabledPlugins
    // monitoringModule.enabledPlugins
    // experimentalModule.enabledPlugins;
in
{
  # Return the complete plugin configuration
  inherit enabledPlugins;
  inherit (marketplacesModule) marketplaces;
}
