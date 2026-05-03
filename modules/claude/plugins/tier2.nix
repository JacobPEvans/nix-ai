# Tier 2 — First-party AI/cloud vendor plugins and MCP integrations
#
# Duplicate Resolution Rule:
#   Plugins in this file are PREFERRED over Tiers 3, 4, 5.
#   Plugins in this file are SUPERSEDED by Tier 1 only when an Anthropic-authored
#   equivalent exists.
#
# Marketplaces in this tier:
#   - openai-codex (openai/codex-plugin-cc, 17071★)
#       Official OpenAI Codex plugin. Supersedes the community variant
#       codex@cc-dev-tools in tier5.nix.
#   - claude-plugins-official/external_plugins/* (parent repo 18410★)
#       Curated MCP integrations to first-party services hosted in the
#       claude-plugins-official marketplace, distinct from the
#       Anthropic-authored core plugins (which live in tier1.nix).

_:

{
  enabledPlugins = {
    # ========================================================================
    # openai-codex — Official OpenAI Codex plugin
    # ========================================================================

    # Codex (Official): code review, adversarial review, task delegation, rescue
    "codex@openai-codex" = true;

    # ========================================================================
    # claude-plugins-official/external_plugins — First-party MCP integrations
    # ========================================================================
    # Most are disabled by default — enable per-repo when authentication is set
    # up and the integration is actively used.

    # Project Management
    "asana@claude-plugins-official" = false; # Requires Asana API token
    "linear@claude-plugins-official" = false; # Requires Linear API key

    # Version Control & Code
    "github@claude-plugins-official" = true; # Requires GITHUB_PERSONAL_ACCESS_TOKEN; gh CLI is the primary path though
    "gitlab@claude-plugins-official" = false; # Requires GitLab API token
    "greptile@claude-plugins-official" = false; # Removed 2026-03-20: not worth cost

    # Documentation & Context
    "context7@claude-plugins-official" = true; # CONTEXT7_API_KEY optional

    # Backend & Infrastructure
    "firebase@claude-plugins-official" = false;
    "supabase@claude-plugins-official" = false;
    "stripe@claude-plugins-official" = false;

    # Testing & Automation
    # Playwright (Tier 2 keeper) — supersedes playwright@claude-skills (Tier 4)
    # which is disabled in tier4.nix.
    "playwright@claude-plugins-official" = true;

    # Frameworks
    "laravel-boost@claude-plugins-official" = false;

    # Communication
    "slack@claude-plugins-official" = true; # Requires Slack OAuth

    # Other
    "serena@claude-plugins-official" = false; # Requires Serena API key
  };
}
