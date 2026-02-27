# Claude Statusline Module
#
# Multi-line statusline for Claude Code using @owloops/claude-powerline.
# Uses bunx at runtime for simplicity - no build-time hashes to maintain.
#
# This module follows NixOS module patterns:
# - Options defined in options.nix
# - Theme implementation in powerline.nix
# - Config logic uses lib.mkIf for conditional activation
#
# Usage:
#   programs.claudeStatusline.enable = true;
#
# Configuration is hardcoded to Rose Pine theme with capsule style.
# See powerline.nix for the full configuration.
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.claudeStatusline;
in
{
  imports = [
    ./options.nix
    ./powerline.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      # Prevent conflicts between old and new statusline modules
      {
        assertion = !(config.programs.claude.statusLine.enhanced.enable or false);
        message = ''
          Both programs.claude.statusLine.enhanced and programs.claudeStatusline are enabled.

          This creates a conflict as both modules will try to deploy the statusline.
          Please use only one statusline module. The programs.claudeStatusline module
          is the new recommended interface.

          To fix:
          1. Set programs.claude.statusLine.enhanced.enable = false;
          2. Use programs.claudeStatusline with the powerline theme
        '';
      }
    ];
  };
}
