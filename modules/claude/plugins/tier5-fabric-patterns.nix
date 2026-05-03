# Marketplace: fabric-patterns (synthetic)
# Source: github.com/danielmiessler/fabric (curated subset wrapped via marketplace-overrides.nix)
# Stars (verified 2026-05-02): 41428 (upstream)
# Priority Tier: 5 (Niche — pattern library, large skill index footprint)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are SUPERSEDED by ALL higher tiers.
#
# DISABLED — 50+ tiny analyze_*/extract_*/write_* skills bloat the eager
# skill index for marginal value. Use the Fabric MCP server instead, which
# is already loaded on-demand:
#   mcp__fabric__fabric_list_patterns
#   mcp__fabric__fabric_run_pattern
# Re-enable per-repo if you actually invoke the slash-command form often.

_:

{
  enabledPlugins = {
    "fabric-patterns@fabric-patterns" = false;
  };
}
