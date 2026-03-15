# Verify evaluated config values match expected values.
# Tests the FULL module output (options.nix defaults + claude-config.nix overrides).
# Catches unintended changes to either file.
{ pkgs, hmConfig }:
let
  cfg = hmConfig.config.programs.claude;
  checks = [
    {
      name = "enable";
      actual = cfg.enable;
      expected = true;
    }
    {
      name = "alwaysThinkingEnabled";
      actual = cfg.settings.alwaysThinkingEnabled;
      expected = true;
    }
    {
      name = "cleanupPeriodDays";
      actual = cfg.settings.cleanupPeriodDays;
      expected = 30;
    }
    {
      name = "autoUpdatesChannel";
      actual = cfg.autoUpdatesChannel;
      expected = "stable";
    }
    {
      name = "teammateMode";
      actual = cfg.teammateMode;
      expected = "auto";
    }
    {
      name = "showTurnDuration";
      actual = cfg.showTurnDuration;
      expected = true;
    }
    {
      name = "sandbox.enabled";
      actual = cfg.settings.sandbox.enabled;
      expected = false;
    }
    {
      name = "sandbox.autoAllowBashIfSandboxed";
      actual = cfg.settings.sandbox.autoAllowBashIfSandboxed;
      expected = true;
    }
    {
      name = "statusLine.enable";
      actual = cfg.statusLine.enable;
      expected = true;
    }
    {
      name = "schemaUrl";
      actual = cfg.settings.schemaUrl;
      expected = "https://json.schemastore.org/claude-code-settings.json";
    }
    {
      name = "plugins.allowRuntimeInstall";
      actual = cfg.plugins.allowRuntimeInstall;
      expected = true;
    }
    {
      name = "features.pluginSchemaVersion";
      actual = cfg.features.pluginSchemaVersion;
      expected = 1;
    }
    {
      name = "remoteControlAtStartup";
      actual = cfg.remoteControlAtStartup;
      expected = true;
    }
    {
      name = "apiKeyHelper.enable";
      actual = cfg.apiKeyHelper.enable;
      expected = true;
    }
  ];
  failures = builtins.filter (c: c.actual != c.expected) checks;
  failureMsg = builtins.concatStringsSep "\n" (
    map (
      c: "  ${c.name}: expected ${builtins.toJSON c.expected}, got ${builtins.toJSON c.actual}"
    ) failures
  );
in
assert failures == [ ] || throw "Default value regression:\n${failureMsg}";
pkgs.runCommand "check-defaults-regression" { } ''
  echo "Defaults regression: ${toString (builtins.length checks)} critical defaults verified"
  touch $out
''
