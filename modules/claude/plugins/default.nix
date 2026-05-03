# Claude Code Plugins - Main Configuration
#
# File layout: one file per marketplace, prefixed with priority tier.
# See README.md in this directory for the full priority/duplicate-resolution rules.
#
# Tier 1 — Anthropic Official
# Tier 2 — First-party AI/cloud vendors (Codex official, GitHub/Slack/etc. MCP integrations)
# Tier 3 — Personal (jacobpevans-cc-plugins, auto-discovered)
# Tier 4 — Community by GitHub-stars popularity
# Tier 5 — Niche / specialty
#
# Each tier-N file exports `enabledPlugins`. The marketplaces module exports
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

  # Tier 1 — Anthropic Official
  tier1ClaudePluginsOfficial = import ./tier1-claude-plugins-official.nix { };
  tier1AnthropicAgentSkills = import ./tier1-anthropic-agent-skills.nix { };

  # Tier 2 — First-party AI/cloud vendor plugins and MCP integrations
  tier2OpenaiCodex = import ./tier2-openai-codex.nix { };
  tier2ExternalMcpIntegrations = import ./tier2-external-mcp-integrations.nix { };

  # Tier 3 — Personal (auto-discovered from flake input)
  tier3Jacobpevans = import ./tier3-jacobpevans-cc-plugins.nix {
    inherit lib jacobpevans-cc-plugins;
  };

  # Tier 4 — Community by popularity (stars verified in each file header)
  tier4ClaudeCodeWorkflows = import ./tier4-claude-code-workflows.nix { };
  tier4SuperpowersMarketplace = import ./tier4-superpowers-marketplace.nix { };
  tier4CcMarketplace = import ./tier4-cc-marketplace.nix { };
  tier4ClaudeSkills = import ./tier4-claude-skills.nix { };

  # Tier 5 — Niche / specialty (one file per marketplace)
  tier5LunarClaude = import ./tier5-lunar-claude.nix { };
  tier5ClaudeCodePluginsPlus = import ./tier5-claude-code-plugins-plus.nix { };
  tier5BitwardenMarketplace = import ./tier5-bitwarden-marketplace.nix { };
  tier5CcDevTools = import ./tier5-cc-dev-tools.nix { };
  tier5FabricPatterns = import ./tier5-fabric-patterns.nix { };
  tier5HuggingfaceSkills = import ./tier5-huggingface-skills.nix { };
  tier5ObsidianSkills = import ./tier5-obsidian-skills.nix { };
  tier5AxtonObsidianVisualSkills = import ./tier5-axton-obsidian-visual-skills.nix { };
  tier5VisualExplainerMarketplace = import ./tier5-visual-explainer-marketplace.nix { };
  tier5BrowserUseSkills = import ./tier5-browser-use-skills.nix { };
  tier5VctCriblPackValidatorSkills = import ./tier5-vct-cribl-pack-validator-skills.nix { };
  tier5Wakatime = import ./tier5-wakatime.nix { };

  # Merge all enabled plugins. Tier ordering reflects priority — every key
  # contains its `@marketplace` suffix so collisions across files would be a
  # bug (would show up at evaluation time).
  enabledPlugins =
    tier1ClaudePluginsOfficial.enabledPlugins
    // tier1AnthropicAgentSkills.enabledPlugins
    // tier2OpenaiCodex.enabledPlugins
    // tier2ExternalMcpIntegrations.enabledPlugins
    // tier3Jacobpevans.enabledPlugins
    // tier4ClaudeCodeWorkflows.enabledPlugins
    // tier4SuperpowersMarketplace.enabledPlugins
    // tier4CcMarketplace.enabledPlugins
    // tier4ClaudeSkills.enabledPlugins
    // tier5LunarClaude.enabledPlugins
    // tier5ClaudeCodePluginsPlus.enabledPlugins
    // tier5BitwardenMarketplace.enabledPlugins
    // tier5CcDevTools.enabledPlugins
    // tier5FabricPatterns.enabledPlugins
    // tier5HuggingfaceSkills.enabledPlugins
    // tier5ObsidianSkills.enabledPlugins
    // tier5AxtonObsidianVisualSkills.enabledPlugins
    // tier5VisualExplainerMarketplace.enabledPlugins
    // tier5BrowserUseSkills.enabledPlugins
    // tier5VctCriblPackValidatorSkills.enabledPlugins
    // tier5Wakatime.enabledPlugins;
in
{
  inherit enabledPlugins;
  inherit (marketplacesModule) marketplaces;
}
