# Claude Code Plugin Marketplaces
#
# CRITICAL: Marketplace Keys MUST Match Manifest Names
# ============================================================================
# Each key MUST match the `name` field in the repo's .claude-plugin/marketplace.json
#
# Example:
#   GitHub repo: anthropics/skills
#   manifest name: "anthropic-agent-skills" (from marketplace.json)
#   Nix key: "anthropic-agent-skills" ← MUST MATCH manifest name
#   Plugin reference: "example-skills@anthropic-agent-skills"
#
# DO NOT use arbitrary keys like "skills" or GitHub paths like "anthropics/skills"
#
# Required fields per marketplace:
#   - source.type: "github" (lowercase, always)
#   - source.url: "owner/repo" format (GitHub path)
#
# How to find manifest names: See docs/TESTING-MARKETPLACES.md
# ============================================================================
#
# IMPORTANT: Marketplace URL Format and Plugin References
# ========================================================================
# INPUT FORMAT (what we define here):
#   type: "github"     (for GitHub repositories)
#   url: "owner/repo"  (GitHub org/repo format, NOT full URL)
#
# OUTPUT FORMAT (after transformation via lib/claude-registry.nix):
#   source: "github"
#   repo: <value from source.url>  # The actual GitHub path for fetching
#
# MARKETPLACE DISPLAY NAMES:
# - Standard: Key = "owner/repo", display name = repo (extracted by getMarketplaceName)
# - Special: Some marketplaces use org-name as display (e.g., WakaTime uses "wakatime")
# - Plugin references: "plugin-name@display-name" (e.g., "claude-code-wakatime@wakatime")
#
# SPECIAL CASES (key differs from owner/repo pattern):
# - WakaTime: Key = "wakatime", URL = "wakatime/claude-code-wakatime"
#   Official: claude plugin i claude-code-wakatime@wakatime
# - When in doubt, check the official plugin install command
#
# WHY THIS WORKS:
# - The toClaudeMarketplaceFormat function (lib/claude-registry.nix)
#   converts both "github" and "git" types to "source: github"
# - The source.url becomes the repo value in settings.json (for fetching)
# - The KEY becomes the display name (for plugin references)
# - This ensures Claude Code can locate and fetch the marketplace
# ========================================================================
#
# WARNING: AGGREGATION MARKETPLACES TO AVOID
# ============================================================================
# DO NOT use "awesome-claude-code-plugins" (ccplugins/awesome-claude-code-plugins)
# It is an AGGREGATION that copies plugins from other sources without regular updates.
# Always find and use the TRUE SOURCE for plugins:
#   - Plugins from claudecodecommands.directory → use "cc-marketplace"
#   - Check plugin.json homepage/author fields to find original source
# ============================================================================

{
  lib,
  ...
}:

let
  # Validate marketplace entry has correct nested structure
  # Claude Code schema: { "id": { source: { type: "git", url: "..." } } }
  validateMarketplace =
    name: value:
    assert lib.assertMsg (builtins.isAttrs value)
      "Marketplace '${name}' must be an attrset, got ${builtins.typeOf value}";
    assert lib.assertMsg (
      value ? source && builtins.isAttrs value.source
    ) "Marketplace '${name}' must have a 'source' attrset";
    assert lib.assertMsg (
      value.source ? type && builtins.isString value.source.type
    ) "Marketplace '${name}.source' must have a 'type' string (git, github, local)";
    assert lib.assertMsg (
      value.source ? url && builtins.isString value.source.url
    ) "Marketplace '${name}.source' must have a 'url' string";
    true;

  # ============================================================================
  # Marketplace Definitions
  # ============================================================================
  # IMPORTANT: Keys MUST match the `name` field in each repo's marketplace.json
  # This ensures plugin references like "plugin@marketplace" work correctly.
  # See docs/CLAUDE-MARKETPLACE-ARCHITECTURE.md for details.
  # ============================================================================
  marketplaces = {
    # --- Personal Plugins (listed first) ---
    # User's custom Claude Code plugins - name matches manifest
    "jacobpevans-cc-plugins" = {
      source = {
        type = "github";
        url = "JacobPEvans/claude-code-plugins";
      };
    };

    # --- Official Anthropic ---
    "claude-plugins-official" = {
      source = {
        type = "github";
        url = "anthropics/claude-plugins-official";
      };
    };
    "anthropic-agent-skills" = {
      source = {
        type = "github";
        url = "anthropics/skills";
      };
    };

    # --- Community ---
    "cc-marketplace" = {
      source = {
        type = "github";
        url = "ananddtyagi/cc-marketplace";
      };
    };
    "bills-claude-skills" = {
      source = {
        type = "github";
        url = "BillChirico/bills-claude-skills";
      };
    };
    "superpowers-marketplace" = {
      source = {
        type = "github";
        url = "obra/superpowers-marketplace";
      };
    };

    # --- Infrastructure & DevOps ---
    "lunar-claude" = {
      source = {
        type = "github";
        url = "basher83/lunar-claude";
      };
    };
    "claude-code-plugins-plus" = {
      source = {
        type = "github";
        url = "jeremylongshore/claude-code-plugins-plus";
      };
    };
    "claude-code-workflows" = {
      source = {
        type = "github";
        url = "wshobson/agents";
      };
    };

    # --- Time Tracking ---
    "wakatime" = {
      source = {
        type = "github";
        url = "wakatime/claude-code-wakatime";
      };
    };

    # --- Claude Skills Marketplace ---
    "claude-skills" = {
      source = {
        type = "github";
        url = "secondsky/claude-skills";
      };
    };

    # --- Additional Community Marketplaces ---
    # Multi-model AI integrations (OpenAI, Gemini) and notifications
    "cc-dev-tools" = {
      source = {
        type = "github";
        url = "Lucklyric/cc-dev-tools";
      };
    };

    # --- Obsidian Skills ---
    # Canonical Obsidian skills from kepano (markdown, bases, canvas, CLI, utilities)
    "obsidian-skills" = {
      source = {
        type = "github";
        url = "kepano/obsidian-skills";
      };
    };

    # Independent visual diagram skills (Excalidraw, Mermaid, Canvas Creator)
    "obsidian-visual-skills" = {
      source = {
        type = "github";
        url = "axtonliu/axton-obsidian-visual-skills";
      };
    };
  };

  # Validate all marketplaces at evaluation time
  validatedMarketplaces = lib.mapAttrs validateMarketplace marketplaces;
in
# Force evaluation of validations
assert lib.all (x: x) (lib.attrValues validatedMarketplaces);
{
  inherit marketplaces;
}
