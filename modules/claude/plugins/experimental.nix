# Experimental Plugins
#
# WARNING: Experimental plugins may have autonomous behavior
#
# CRITICAL: Plugin Reference Format
# ============================================================================
# Format: "plugin-name@marketplace-name"
#
# The marketplace-name MUST match the key in marketplaces.nix, which MUST
# match the `name` field from the marketplace's .claude-plugin/marketplace.json
#
# How to verify: See docs/TESTING-MARKETPLACES.md
# ============================================================================

_:

{
  enabledPlugins = {
    # ========================================================================
    # Autonomous Iteration
    # ========================================================================
    # ralph-loop: autonomous iteration loops with file/git history preservation
    # Commands: /ralph-loop, /cancel-ralph
    "ralph-loop@claude-plugins-official" = true;

    # ========================================================================
    # Multi-Model AI Integrations (cc-dev-tools)
    # ========================================================================
    # WARNING: These plugins invoke external AI models (OpenAI, Google)

    # Codex: OpenAI GPT integration for high-reasoning coding tasks
    # Auto-selects GPT-5.2-Codex for coding or GPT-5.2 for reasoning
    "codex@cc-dev-tools" = true;

    # Gemini: Google Gemini 3 Pro integration for research and reasoning
    # Includes web search capabilities and session resumption
    "gemini@cc-dev-tools" = true;

    # Telegram Notifier: Notifications for Claude Code events
    # Hook-based (response completion, subagent tasks, system notifications)
    # Requires: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID env vars
    "telegram-notifier@cc-dev-tools" = false; # Enable after configuring tokens
  };
}
