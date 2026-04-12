# Claude Code Plugins - Fabric (Daniel Miessler)
#
# Curated subset of Fabric's 252+ AI prompt patterns wrapped as Claude Code
# skills via a synthetic marketplace (see marketplace-overrides.nix
# fabricMarketplace derivation).
#
# Pattern selection lives in modules/claude/fabric-curated-patterns.json.
# Each pattern becomes a discoverable skill in Claude Code sessions.

_:

{
  enabledPlugins = {
    "fabric-patterns@fabric-patterns" = true;
  };
}
