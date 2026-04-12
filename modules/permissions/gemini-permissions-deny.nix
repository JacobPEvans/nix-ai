# Gemini CLI Permanently Blocked Commands (DENY List / excludeTools)
#
# Uses unified permission definitions from ai-cli/common/permissions.nix
# with Gemini-specific formatting via formatters.nix.
#
# FORMAT: ShellTool(cmd) for blocked shell commands
#
# SINGLE SOURCE OF TRUTH:
# Command definitions are in ai-cli/common/permissions.nix
# This file only applies Gemini-specific formatting.
#
# SECURITY PHILOSOPHY:
# - These are truly catastrophic operations (system destruction, data exfiltration)
# - No user confirmation can override these blocks
# - If a legitimate use case arises, edit ai-cli/common/permissions.nix

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
  # Export denyRules for the Policy Engine (TOML)
  denyRules = formatters.gemini.formatDenyRules permissions;

  # DEPRECATED: Export excludeTools (permanently blocked commands)
  excludeTools = formatters.gemini.formatExcludeTools permissions;
}
