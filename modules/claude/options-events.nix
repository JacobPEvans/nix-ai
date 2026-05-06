# Claude Code Module — Event hook + MCP server options
#
# Hooks fire on Claude Code lifecycle events (preToolUse, sessionStart, etc.)
# and run as scripts in ~/.claude/hooks/. MCP servers expose Model Context
# Protocol tools/resources to the running session.
{ lib, ... }:
let
  inherit (import ./options-types.nix { inherit lib; }) mcpServerModule hookType;
in
{
  options.programs.claude = {
    # Hooks - fully implemented in modules/claude/settings.nix
    # Generates executable scripts in ~/.claude/hooks/ via home.file.
    hooks = {
      preToolUse = lib.mkOption {
        type = hookType;
        default = null;
      };
      postToolUse = lib.mkOption {
        type = hookType;
        default = null;
      };
      userPromptSubmit = lib.mkOption {
        type = hookType;
        default = null;
      };
      stop = lib.mkOption {
        type = hookType;
        default = null;
      };
      subagentStop = lib.mkOption {
        type = hookType;
        default = null;
      };
      sessionStart = lib.mkOption {
        type = hookType;
        default = null;
      };
      sessionEnd = lib.mkOption {
        type = hookType;
        default = null;
      };
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf mcpServerModule;
      default = { };
    };
  };
}
