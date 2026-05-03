# Marketplace: claude-plugins-official
# Source: github.com/anthropics/claude-plugins-official
# Stars (verified 2026-05-02): 18410
# Priority Tier: 1 (Anthropic Official)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: ALL other tiers (2, 3, 4, 5).
#   Variants from this marketplace are SUPERSEDED by:  none.
#
# When a role (e.g., code-reviewer, playwright) ships from both Tier 1 and a
# lower tier, KEEP the Tier 1 variant and disable the lower-tier duplicate
# in its respective tier-N file.
#
# This file holds first-party Anthropic plugins that are part of the core
# claude-plugins-official marketplace. Third-party MCP integrations (GitHub,
# Slack, Stripe, etc.) that ALSO live in claude-plugins-official upstream
# are kept in tier2-external-mcp-integrations.nix because their priority
# logic is "first-party AI/cloud vendor", not "Anthropic-authored plugin".

_:

{
  enabledPlugins = {
    # Git Workflow (essential)
    "commit-commands@claude-plugins-official" = true;

    # Code Review (essential) — Tier 1 keepers; supersedes Tier 4 duplicates
    # in tier4-claude-code-workflows.nix (codebase-cleanup, tdd-workflows,
    # code-refactoring all ship a code-reviewer agent that we disable there).
    "code-review@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;

    # Feature Development — provides feature-dev:code-reviewer (high-confidence
    # filter variant, complementary to pr-review-toolkit:code-reviewer).
    "feature-dev@claude-plugins-official" = true;

    # Security (useful for infra work)
    "security-guidance@claude-plugins-official" = true;

    # Plugin Development (user maintains claude-code-plugins repo)
    "plugin-dev@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;

    # Setup & Management
    "claude-code-setup@claude-plugins-official" = true;
    "claude-md-management@claude-plugins-official" = true;

    # Language Servers & Developer Tools
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = false; # Minimal TS usage
  };
}
