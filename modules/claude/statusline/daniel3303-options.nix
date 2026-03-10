# ClaudeCodeStatusLine Options (daniel3303)
#
# 2-line statusline format focusing on rate limits and token state.
# Original repository: https://github.com/daniel3303/ClaudeCodeStatusLine
#
{ lib, ... }:

{
  options.programs.claudeStatuslineDaniel3303 = {
    enable = lib.mkEnableOption "Claude Code statusline (ClaudeCodeStatusLine by daniel3303) — 2-line format";
  };
}
