# Marketplace: bitwarden-marketplace
# Source: github.com/bitwarden/ai-plugins
# Stars (verified 2026-05-02): 90
# Priority Tier: 5 (Niche — enterprise session analysis)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are SUPERSEDED by ALL higher tiers.
#
# Two plugins kept: claude-retrospective (3 skills), claude-config-validator
# (1 skill). Bitwarden-internal plugins are NOT enabled — see comment below.

_:

{
  enabledPlugins = {
    "claude-retrospective@bitwarden-marketplace" = true;
    "claude-config-validator@bitwarden-marketplace" = true;

    # NOT enabled — Bitwarden-specific:
    # bitwarden-code-review, bitwarden-software-engineer,
    # bitwarden-security-engineer, bitwarden-product-analyst, bitwarden-init,
    # atlassian-reader, bitwarden-atlassian-tools.
  };
}
