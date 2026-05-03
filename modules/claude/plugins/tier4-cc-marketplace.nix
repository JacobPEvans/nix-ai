# Marketplace: cc-marketplace
# Source: github.com/ananddtyagi/cc-marketplace
# Stars (verified 2026-05-02): 679
# Priority Tier: 4 (Community — official source for claudecodecommands.directory)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tier 5.
#   Variants from this marketplace are SUPERSEDED by:  Tiers 1, 2, 3, and
#   the higher-popularity Tier 4 (claude-code-workflows).

_:

{
  enabledPlugins = {
    # Essential issue analysis + worktree creation utilities (unique to this marketplace).
    "analyze-issue@cc-marketplace" = true;
    "create-worktrees@cc-marketplace" = true;

    # User actively uses Python — kept for python-expert agent (unique).
    "python-expert@cc-marketplace" = true;

    # CI/CD, cloud infra, monitoring, deployment automation (unique).
    "devops-automator@cc-marketplace" = true;

    # NOT enabled: double-check (unnecessary), infrastructure-maintainer (too generic),
    # monitoring-observability-specialist (Splunk repos don't need this),
    # awesome-claude-code-plugins (AGGREGATION — use true sources directly).
  };
}
