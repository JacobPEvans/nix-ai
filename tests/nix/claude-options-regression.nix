# Verify all expected option paths exist in the evaluated module.
# Catches accidentally dropped options (e.g., from refactoring with lib;).
{ pkgs, hmConfig }:
let
  cfg = hmConfig.config.programs.claude;

  expectedClaudeOptions = [
    "agents"
    "apiKeyHelper"
    "attribution"
    "autoUpdatesChannel"
    "commands"
    "effortLevel"
    "enable"
    "features"
    "hooks"
    "mcpServers"
    "model"
    "plugins"
    "remoteControlAtStartup"
    "settings"
    "showTurnDuration"
    "skills"
    "statusLine"
    "teammateMode"
    "trustedProjectDirs"
  ];
  actualClaudeOptions = builtins.attrNames cfg;
  missingClaudeOptions = builtins.filter (
    o: !(builtins.elem o actualClaudeOptions)
  ) expectedClaudeOptions;

  expectedSettingsOptions = [
    "additionalDirectories"
    "alwaysThinkingEnabled"
    "cleanupPeriodDays"
    "env"
    "permissions"
    "sandbox"
    "schemaUrl"
  ];
  actualSettingsOptions = builtins.attrNames cfg.settings;
  missingSettingsOptions = builtins.filter (
    s: !(builtins.elem s actualSettingsOptions)
  ) expectedSettingsOptions;

  expectedHookOptions = [
    "postToolUse"
    "preToolUse"
    "sessionEnd"
    "sessionStart"
    "stop"
    "subagentStop"
    "userPromptSubmit"
  ];
  actualHookOptions = builtins.attrNames cfg.hooks;
  missingHookOptions = builtins.filter (h: !(builtins.elem h actualHookOptions)) expectedHookOptions;

  expectedPermissionOptions = [
    "allow"
    "ask"
    "deny"
  ];
  actualPermissionOptions = builtins.attrNames cfg.settings.permissions;
  missingPermissionOptions = builtins.filter (
    p: !(builtins.elem p actualPermissionOptions)
  ) expectedPermissionOptions;

  expectedSandboxOptions = [
    "autoAllowBashIfSandboxed"
    "enabled"
    "excludedCommands"
  ];
  actualSandboxOptions = builtins.attrNames cfg.settings.sandbox;
  missingSandboxOptions = builtins.filter (
    s: !(builtins.elem s actualSandboxOptions)
  ) expectedSandboxOptions;
in
assert
  missingClaudeOptions == [ ]
  || throw "Missing Claude options: ${builtins.toJSON missingClaudeOptions}";
assert
  missingSettingsOptions == [ ]
  || throw "Missing settings options: ${builtins.toJSON missingSettingsOptions}";
assert
  missingHookOptions == [ ] || throw "Missing hook options: ${builtins.toJSON missingHookOptions}";
assert
  missingPermissionOptions == [ ]
  || throw "Missing permission options: ${builtins.toJSON missingPermissionOptions}";
assert
  missingSandboxOptions == [ ]
  || throw "Missing sandbox options: ${builtins.toJSON missingSandboxOptions}";
pkgs.runCommand "check-options-regression" { } ''
  echo "Option regression: ${toString (builtins.length expectedClaudeOptions)} Claude, ${toString (builtins.length expectedSettingsOptions)} settings, ${toString (builtins.length expectedHookOptions)} hooks, ${toString (builtins.length expectedPermissionOptions)} permissions, ${toString (builtins.length expectedSandboxOptions)} sandbox options verified"
  touch $out
''
