# Marketplace: claude-plugins-official (external_plugins/* subset)
# Source: github.com/anthropics/claude-plugins-official/tree/main/external_plugins
# Stars (verified 2026-05-02): 18410 (parent repo)
# Priority Tier: 2 (First-party AI/cloud vendors curated by Anthropic)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tiers 3, 4, 5.
#   Variants from this marketplace are SUPERSEDED by:  Tier 1 only when an
#   Anthropic-authored equivalent exists (e.g., the community Playwright
#   plugin in claude-skills is superseded by playwright@claude-plugins-official
#   listed here).
#
# These plugins are curated MCP integrations to first-party services
# (GitHub, Slack, Stripe, Firebase, etc.) hosted in the claude-plugins-official
# marketplace but distinct from Anthropic-authored core plugins (which live
# in tier1-claude-plugins-official.nix). They follow the priority logic of
# "first-party vendor integration", hence Tier 2.
#
# Most are disabled by default — enable per-repo when authentication is set up
# and the integration is actively used.

_:

{
  enabledPlugins = {
    # ========================================================================
    # Project Management
    # ========================================================================
    "asana@claude-plugins-official" = false; # Requires Asana API token
    "linear@claude-plugins-official" = false; # Requires Linear API key

    # ========================================================================
    # Version Control & Code
    # ========================================================================
    "github@claude-plugins-official" = true; # Requires GITHUB_PERSONAL_ACCESS_TOKEN; gh CLI is the primary path though
    "gitlab@claude-plugins-official" = false; # Requires GitLab API token
    "greptile@claude-plugins-official" = false; # Removed 2026-03-20: not worth cost

    # ========================================================================
    # Documentation & Context
    # ========================================================================
    "context7@claude-plugins-official" = true; # CONTEXT7_API_KEY optional

    # ========================================================================
    # Backend & Infrastructure
    # ========================================================================
    "firebase@claude-plugins-official" = false;
    "supabase@claude-plugins-official" = false;
    "stripe@claude-plugins-official" = false;

    # ========================================================================
    # Testing & Automation
    # ========================================================================
    # Playwright (Tier 2 keeper) — supersedes playwright@claude-skills (Tier 4)
    # which is disabled in tier4-claude-skills.nix.
    "playwright@claude-plugins-official" = true;

    # ========================================================================
    # Frameworks
    # ========================================================================
    "laravel-boost@claude-plugins-official" = false;

    # ========================================================================
    # Communication
    # ========================================================================
    "slack@claude-plugins-official" = true; # Requires Slack OAuth

    # ========================================================================
    # Other
    # ========================================================================
    "serena@claude-plugins-official" = false; # Requires Serena API key
  };
}
