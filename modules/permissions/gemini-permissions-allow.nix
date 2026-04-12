# Gemini CLI Auto-Approved Commands (ALLOW List)
#
# Uses unified permission definitions from ai-cli/common/permissions.nix
# with Gemini-specific formatting via formatters.nix.
#
# FORMAT: ShellTool(cmd) for shell commands, plus core tools like ReadFileTool
#
# SINGLE SOURCE OF TRUTH:
# Command definitions are in ai-cli/common/permissions.nix
# This file only applies Gemini-specific formatting.
#
# CRITICAL - tools.allowed vs tools.core:
# =========================================
# This exports "allowedTools" which maps to "tools.allowed" in settings.json.
# DO NOT rename this to "coreTools" - that would be WRONG!
#
# Per the official Gemini CLI schema:
# - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
# - tools.core = "Allowlist to RESTRICT built-in tools to a specific set" (LIMITS usage!)
#
# Using tools.core LIMITS what tools Gemini can use, it does NOT grant permissions.
# Schema: https://github.com/google-gemini/gemini-cli/blob/main/schemas/settings.schema.json

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
  # Export allowRules for the Policy Engine (TOML)
  allowRules = formatters.gemini.formatAllowRules permissions;

  # DEPRECATED: Export allowedTools list for tools.allowed (settings.json)
  # Maps to "tools.allowed" in settings.json - NOT "tools.core"!
  # Combines Gemini-specific tools with formatted shell commands
  allowedTools = formatters.gemini.formatAllowedTools permissions;
}
