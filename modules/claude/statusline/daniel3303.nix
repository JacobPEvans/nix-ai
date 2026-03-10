# ClaudeCodeStatusLine Implementation (daniel3303, locally forked)
#
# Based on daniel3303's ClaudeCodeStatusLine:
# https://github.com/daniel3303/ClaudeCodeStatusLine
#
# Local fork at modules/claude/statusline/claude-statusline.sh
# Patch: cwd shows last 2 path components (e.g., nix-ai/main) instead of basename only
#
# The script:
#   - Reads JSON from stdin with Claude Code status data
#   - Outputs 1 line with pipe-delimited segments: model | cwd@branch | tokens/total | effort | 5h % | 7d % | extra
#   - Supports multiple auth methods (env var, macOS Keychain, .credentials.json, GNOME Keyring)
#   - Caches usage data for 60 seconds at /tmp/claude/statusline-usage-cache.json
#   - Color thresholds: green <50% → yellow ≥50% → orange ≥70% → red ≥90%
#
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claudeStatuslineDaniel3303;

  # Local fork of daniel3303's script with cwd patch applied
  statuslineScript = ./claude-statusline.sh;

in
{
  config = lib.mkIf cfg.enable {
    programs.claude.statusLine = {
      enable = true;
      script = ''
        #!/usr/bin/env bash
        # Based on ClaudeCodeStatusLine by daniel3303
        # https://github.com/daniel3303/ClaudeCodeStatusLine
        exec ${pkgs.bash}/bin/bash ${statuslineScript} "$@"
      '';
    };
  };
}
