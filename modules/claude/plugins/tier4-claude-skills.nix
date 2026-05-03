# Marketplace: claude-skills
# Source: github.com/secondsky/claude-skills
# Stars (verified 2026-05-02): 129
# Priority Tier: 4 (Community — single-skill specialty plugins)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tier 5.
#   Variants from this marketplace are SUPERSEDED by:  Tiers 1, 2, 3, and the
#   higher-popularity Tier 4 marketplaces.
#
# Each plugin here is a single specialty skill loaded for every session.
# Disable plugins that aren't in the user's day-to-day stack — re-enable
# per-repo via committed .claude/settings.json overrides when relevant.

_:

{
  enabledPlugins = {
    # ========================================================================
    # API design (general utility — KEEP)
    # ========================================================================
    "api-design-principles@claude-skills" = true;
    "rest-api-design@claude-skills" = true;

    # ========================================================================
    # Authentication (KEEP one — better-auth covers OAuth flows too)
    # ========================================================================
    "better-auth@claude-skills" = true;
    # DISABLED — superseded by better-auth above.
    "oauth-implementation@claude-skills" = false;

    # ========================================================================
    # Disabled — not in user's stack
    # ========================================================================
    # No GraphQL/WebSocket usage in current repos:
    "graphql-implementation@claude-skills" = false;
    "websocket-implementation@claude-skills" = false;

    # No web app dev — CSRF/XSS exposure surfaces aren't part of this stack:
    "csrf-protection@claude-skills" = false;
    "xss-prevention@claude-skills" = false;

    # No JS/TS testing in current repos:
    "jest-generator@claude-skills" = false;
    "vitest-testing@claude-skills" = false;

    # Superseded by Tier 2 playwright@claude-plugins-official:
    "playwright@claude-skills" = false;

    # CI vulnerability scanning handles this; no agent role needed:
    "vulnerability-scanning@claude-skills" = false;

    # No recommendation-engine work in current repos:
    "recommendation-engine@claude-skills" = false;

    # Light DB work; ad-hoc EXPLAIN sufficient:
    "sql-query-optimization@claude-skills" = false;
  };
}
