# Marketplace: superpowers-marketplace
# Source: github.com/obra/superpowers-marketplace
# Stars (verified 2026-05-02): 925
# Priority Tier: 4 (Community — Jesse Vincent / obra)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tier 5.
#   Variants from this marketplace are SUPERSEDED by:  Tiers 1, 2, 3, and the
#   highest-popularity Tier 4 (claude-code-workflows) when role overlaps.

_:

{
  enabledPlugins = {
    # Core enhancement suite — keep the canonical plugin.
    "superpowers@superpowers-marketplace" = true;

    # DISABLED — niche experiments not in active use.
    "superpowers-lab@superpowers-marketplace" = false;

    # DISABLED — plugin-development helpers superseded by Tier 1
    # plugin-dev@claude-plugins-official.
    "superpowers-developing-for-claude-code@superpowers-marketplace" = false;

    # Already disabled — auto-continuation not in use.
    # "double-shot-latte@superpowers-marketplace" = false;
  };
}
