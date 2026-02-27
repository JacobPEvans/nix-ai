# Claude Statusline Options
#
# Declarative statusline configuration for Claude Code.
# Uses @owloops/claude-powerline via bunx at runtime.
{ lib, ... }:

{
  options.programs.claudeStatusline = {
    enable = lib.mkEnableOption "Claude Code statusline (claude-powerline)";
  };
}
