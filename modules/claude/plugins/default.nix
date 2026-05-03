# Claude Code Plugins - Main Configuration
#
# File layout: one file per priority tier. Within each tier file, marketplaces
# are clearly sectioned with header comments. See README.md for the full
# duplicate-resolution rules.
#
# Tier 1 — Anthropic Official
# Tier 2 — First-party AI/cloud vendors (Codex official, GitHub/Slack/etc. MCP integrations)
# Tier 3 — Personal (jacobpevans-cc-plugins, auto-discovered)
# Tier 4 — Community by GitHub-stars popularity
# Tier 5 — Niche / specialty
#
# Each tier file exports `enabledPlugins`. The marketplaces module exports
# `marketplaces`. All `enabledPlugins` attrsets are merged below.

{
  lib,
  marketplaceInputs,
  ...
}:

let
  # Extract specific inputs needed by sub-modules
  inherit (marketplaceInputs) jacobpevans-cc-plugins;

  # Marketplace definitions (separate from plugin enablement)
  marketplacesModule = import ./marketplaces.nix { inherit lib; };

  # One file per priority tier
  tier1 = import ./01-official.nix { };
  tier2 = import ./02-vendors.nix { };
  tier3 = import ./03-personal.nix { inherit lib jacobpevans-cc-plugins; };
  tier4 = import ./04-community.nix { };
  tier5 = import ./05-specialty.nix { };

  # Merge all enabled plugins. Tier ordering reflects priority — every key
  # contains its `@marketplace` suffix so collisions across files would be a
  # bug (would show up at evaluation time).
  enabledPlugins =
    tier1.enabledPlugins
    // tier2.enabledPlugins
    // tier3.enabledPlugins
    // tier4.enabledPlugins
    // tier5.enabledPlugins;
in
{
  inherit enabledPlugins;
  inherit (marketplacesModule) marketplaces;
}
