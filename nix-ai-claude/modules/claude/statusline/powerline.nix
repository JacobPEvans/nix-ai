# Powerline Theme - Claude Code Statusline
#
# Multi-line statusline powered by @owloops/claude-powerline.
# Uses bunx at runtime for simplicity - no build-time hashes to maintain.
#
# Repository: https://github.com/Owloops/claude-powerline
# Configuration: ./claude-powerline.json
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claudeStatusline;
  daniel3303Cfg = config.programs.claudeStatuslineDaniel3303;

  # JSON config in separate file to preserve segment order and enable IDE validation
  configFile = ./claude-powerline.json;

in
{
  config = lib.mkIf cfg.enable {
    # Ensure only one statusline implementation is enabled
    assertions = [
      {
        assertion = !daniel3303Cfg.enable;
        message = ''
          Cannot enable both programs.claudeStatusline (powerline) and programs.claudeStatuslineDaniel3303 (daniel3303) simultaneously.
          Choose one statusline implementation or disable both to use Claude Code's default.
        '';
      }
    ];

    programs.claude.statusLine = {
      enable = true;
      script = ''
        #!/usr/bin/env bash
        # Claude Powerline statusline (semver-pinned for stability)
        exec ${pkgs.bun}/bin/bunx @owloops/claude-powerline@'^1' --config=${configFile} "$@"
      '';
    };
  };
}
