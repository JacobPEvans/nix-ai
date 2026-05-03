# Marketplace: openai-codex
# Source: github.com/openai/codex-plugin-cc
# Stars (verified 2026-05-02): 17071
# Priority Tier: 2 (First-party AI vendor)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tiers 3, 4, 5.
#   Variants from this marketplace are SUPERSEDED by:  Tier 1.
#
# This is OpenAI's official Codex plugin. The community variant
# `codex@cc-dev-tools` is disabled in tier5-cc-dev-tools.nix in favor
# of this one.

_:

{
  enabledPlugins = {
    # Codex (Official): code review, adversarial review, task delegation, rescue
    "codex@openai-codex" = true;
  };
}
