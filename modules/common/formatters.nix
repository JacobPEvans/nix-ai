# AI CLI Permission Formatters
#
# Transforms tool-agnostic command definitions into tool-specific formats.
# Each tool has different permission syntax requirements.
#
# FORMATS:
# - Claude Code: Bash(cmd:*) for shell, Read(**) for file tools
# - Gemini CLI: ShellTool(cmd) for shell, ReadFileTool for file tools
# - Copilot CLI: shell(cmd) patterns for runtime flags
# - Crush: shell_allowlist for permissions config

{ lib }:

let
  # Flatten nested attribute sets into a list of commands
  # Handles both lists and nested attrsets
  flattenCommands =
    attrs:
    if builtins.isList attrs then
      attrs
    else if builtins.isAttrs attrs then
      lib.flatten (
        lib.mapAttrsToList (
          _name: value:
          if builtins.isList value then
            value
          else if builtins.isAttrs value then
            flattenCommands value
          else
            [ ]
        ) attrs
      )
    else
      [ ];

  # Claude-specific helper: Get all tool-specific permissions (non-shell)
  getClaudeToolPermissions =
    permissions:
    let
      claudePerms = permissions.toolSpecific.claude or { };
      # WebFetch domains from ai-assistant-instructions
      webfetchDomains = permissions.webfetchDomains or [ ];
      webfetchPerms = map (d: "WebFetch(domain:${d})") webfetchDomains;
    in
    (claudePerms.builtin or [ ]) ++ webfetchPerms ++ (claudePerms.read or [ ]);

  # Claude-specific helper: Get tool-specific deny permissions
  getClaudeDenyPermissions =
    permissions:
    let
      # Deny patterns from ai-assistant-instructions (file patterns for the Read tool)
      denyPatterns = permissions.denyPatterns or [ ];
      # Convert patterns to Read(...) format for Claude's deny list.
      # Note: patterns are used as provided; any tilde (~) expansion must be done upstream.
      denyReadPatterns = map (p: "Read(${p})") denyPatterns;
    in
    denyReadPatterns;

in
{
  # ============================================================================
  # CLAUDE CODE FORMATTER
  # ============================================================================
  # Format: Bash(cmd:*) for shell commands
  # The :* suffix is Claude-specific wildcard syntax: it matches "cmd:" followed by any arguments

  claude = {
    # Format a single shell command for Claude
    formatShellCommand = cmd: "Bash(${cmd}:*)";

    # Format a list of shell commands
    formatShellCommands = cmds: map (cmd: "Bash(${cmd}:*)") cmds;

    # Format all allowed commands from permissions (shell + tool-specific + MCP)
    # Note: Tool-specific permissions are placed before shell permissions.
    # This ordering matches formatDenied and ensures consistent evaluation by Claude Code.
    formatAllowed =
      permissions:
      let
        allCommands = flattenCommands permissions.allow;
        shellPermissions = map (cmd: "Bash(${cmd}:*)") allCommands;
        mcpPermissions = permissions.mcpAllow or [ ];
      in
      (getClaudeToolPermissions permissions) ++ mcpPermissions ++ shellPermissions;

    # Format all denied commands (shell + tool-specific + MCP)
    # Note: Tool-specific permissions are placed before shell permissions.
    # This ordering matches formatAllowed and ensures consistent evaluation by Claude Code.
    formatDenied =
      permissions:
      let
        allCommands = flattenCommands permissions.deny;
        shellDenied = map (cmd: "Bash(${cmd}:*)") allCommands;
        mcpPermissions = permissions.mcpDeny or [ ];
      in
      (getClaudeDenyPermissions permissions) ++ mcpPermissions ++ shellDenied;

    # Format all ask commands (require user confirmation)
    # These commands will prompt the user for approval before execution
    formatAsk =
      permissions:
      let
        allCommands = flattenCommands permissions.ask;
        shellPermissions = map (cmd: "Bash(${cmd}:*)") allCommands;
        mcpPermissions = permissions.mcpAsk or [ ];
      in
      mcpPermissions ++ shellPermissions;

    # Export helpers for external use
    getToolPermissions = getClaudeToolPermissions;
    getDenyPermissions = getClaudeDenyPermissions;
  };

  # ============================================================================
  # GEMINI CLI FORMATTER
  # ============================================================================
  # Format: ShellTool(cmd) for shell commands
  # No wildcard suffix - exact command match or prefix match
  #
  # CRITICAL - tools.allowed vs tools.core in settings.json:
  # =========================================================
  # Per the official Gemini CLI schema:
  # - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
  # - tools.core = "Allowlist to RESTRICT built-in tools to a specific set" (LIMITS usage!)
  #
  # This formatter provides formatAllowedTools for the "allowed" key.
  # NEVER use formatAllowedTools output for "core" - that would break permissions!
  # Schema: https://github.com/google-gemini/gemini-cli/blob/main/schemas/settings.schema.json

  gemini = {
    # Format a single shell command for Gemini
    formatShellCommand = cmd: "ShellTool(${cmd})";

    # Format a list of shell commands
    formatShellCommands = cmds: map (cmd: "ShellTool(${cmd})") cmds;

    # Format all auto-approved commands for tools.allowed (NOT tools.core!)
    # Output goes to settings.json "tools.allowed" to bypass confirmation dialog
    formatAllowedTools =
      permissions:
      let
        allCommands = flattenCommands permissions.allow;
        shellTools = map (cmd: "ShellTool(${cmd})") allCommands;
        # Built-in Gemini tools (ReadFileTool, etc.) from permissions.nix
        builtinTools = permissions.toolSpecific.gemini.builtin or [ ];
      in
      builtinTools ++ shellTools;

    # Format all denied commands (excludeTools)
    formatExcludeTools =
      permissions:
      let
        allCommands = flattenCommands permissions.deny;
      in
      map (cmd: "ShellTool(${cmd})") allCommands;

    # Get tool-specific permissions (non-shell)
    getToolPermissions = permissions: permissions.toolSpecific.gemini.builtin or [ ];
  };

  # ============================================================================
  # COPILOT CLI FORMATTER
  # ============================================================================
  # Format: shell(cmd) patterns for --allow-tool and --deny-tool flags
  # Note: Copilot permissions are primarily directory-based in config

  copilot = {
    # Format a single shell command for Copilot
    formatShellCommand = cmd: "shell(${cmd})";

    # Format a list of shell commands
    formatShellCommands = cmds: map (cmd: "shell(${cmd})") cmds;

    # Get trusted directories
    getTrustedFolders =
      permissions:
      let
        dirs = permissions.directories or { };
      in
      (dirs.home or [ ]) ++ (dirs.development or [ ]) ++ (dirs.config or [ ]);

    # Format denied commands for --deny-tool flags
    formatDenyFlags =
      permissions:
      let
        allCommands = flattenCommands permissions.deny;
      in
      map (cmd: "shell(${cmd})") allCommands;
  };

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  utils = {
    # Flatten commands from nested permission structure
    inherit flattenCommands;

    # Count total commands in a permission set
    countCommands = permissions: builtins.length (flattenCommands permissions);

    # Get all categories from permissions
    getCategories = permissions: builtins.attrNames permissions;
  };
}
