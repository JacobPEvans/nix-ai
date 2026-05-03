# Marketplace: cc-dev-tools
# Source: github.com/Lucklyric/cc-dev-tools
# Stars (verified 2026-05-02): 29
# Priority Tier: 5 (Niche — community AI vendor wrappers)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are SUPERSEDED by ALL higher tiers.
#   Specifically, codex@cc-dev-tools is superseded by Tier 2 codex@openai-codex
#   (the official OpenAI plugin).
#
# WARNING: These plugins invoke external AI models (OpenAI, Google).

_:

{
  enabledPlugins = {
    # DISABLED — superseded by Tier 2 codex@openai-codex (official OpenAI plugin).
    "codex@cc-dev-tools" = false;

    # KEEP — no Google-official Claude plugin exists for Gemini delegation.
    "gemini@cc-dev-tools" = true;

    # Already disabled — requires TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID env vars
    # which aren't configured.
    "telegram-notifier@cc-dev-tools" = false;
  };
}
