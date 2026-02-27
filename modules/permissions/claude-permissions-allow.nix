# Claude Code Auto-Approved Commands (ALLOW List)
#
# Uses unified permission definitions from ai-cli/common/permissions.nix
# with Claude-specific formatting via formatters.nix.
#
# FORMAT: Bash(cmd:*) for shell commands, plus tool-specific patterns
#
# SINGLE SOURCE OF TRUTH:
# Command definitions are in ai-cli/common/permissions.nix
# This file only applies Claude-specific formatting.

{
  config,
  lib,
  ...
}:

let
  # Import unified permissions and formatters
  # Error handling: Verify the ai-cli/common module exists and can be imported
  commonPath = ../common;
  aiCommon =
    if builtins.pathExists commonPath then
      import commonPath { inherit lib config; }
    else
      builtins.throw ''
        ERROR: common module not found at ${toString commonPath}

        This wrapper module expects the unified permission system to exist.
        Ensure:
        1. modules/common/default.nix exists
        2. modules/common/permissions.nix exists
        3. modules/common/formatters.nix exists
      '';

  inherit (aiCommon) permissions formatters;

in
{
  # Export allowed permissions list
  # Combines shell commands (Bash(cmd:*)) with tool-specific permissions
  allow = formatters.claude.formatAllowed permissions;
}
