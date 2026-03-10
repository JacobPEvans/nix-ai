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
    ./daniel3303-options.nix
    ./daniel3303.nix
  ];

  config = lib.mkIf cfg.enable { };
}
