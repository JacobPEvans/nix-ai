# ClaudeCodeStatusLine Implementation (daniel3303)
#
# Uses daniel3303's real ClaudeCodeStatusLine script from:
# https://github.com/daniel3303/ClaudeCodeStatusLine
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

  # Fetch the real statusline.sh from daniel3303's repository
  statuslineScript = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/daniel3303/ClaudeCodeStatusLine/refs/heads/main/statusline.sh";
    hash = "sha256-5B8b0pU0BWffhRCmQAeCktitfR8zxSD25VqiC0jn9iU=";
  };

in
{
  config = lib.mkIf cfg.enable {
    programs.claude.statusLine = {
      enable = true;
      script = ''
        #!/usr/bin/env bash
        # ClaudeCodeStatusLine by daniel3303
        # https://github.com/daniel3303/ClaudeCodeStatusLine
        exec ${pkgs.bash}/bin/bash ${statuslineScript} "$@"
      '';
    };
  };
}
