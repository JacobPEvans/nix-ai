# Gemini CLI User-Prompted Commands (ASK List)
#
# Gemini CLI now supports "ask_user" decision via the Policy Engine!
# This file exports rules for commands that require explicit user confirmation.
#
# Uses unified permission definitions from ai-cli/common/permissions.nix
# with Gemini-specific formatting via formatters.nix.

{
  config,
  lib,
  ai-assistant-instructions,
  ...
}:

let
  # Import unified permissions and formatters
  aiCommon = import ../common { inherit lib config ai-assistant-instructions; };
  inherit (aiCommon) permissions formatters;

in
{
  # Export askRules for the Policy Engine (TOML)
  askRules = formatters.gemini.formatAskRules permissions;
}
