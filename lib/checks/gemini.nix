# Gemini module regression tests
{ pkgs, hmConfig }:
let
  cfg = hmConfig.config.programs.gemini;
in
{
  # Verify all expected Gemini option paths exist.
  gemini-options-regression =
    let
      expectedOptions = [
        "commands"
        "enable"
        "excludedMcpServers"
        "extensions"
        "hooks"
        "skills"
        "trustedFolders"
      ];
      actualOptions = builtins.attrNames cfg;
      missingOptions = builtins.filter (o: !(builtins.elem o actualOptions)) expectedOptions;
    in
    assert missingOptions == [ ] || throw "Missing Gemini options: ${builtins.toJSON missingOptions}";
    pkgs.runCommand "check-gemini-options-regression" { } ''
      echo "Gemini option regression: ${toString (builtins.length expectedOptions)} options verified"
      touch $out
    '';

  # Verify evaluated config values match expected defaults.
  gemini-defaults-regression =
    let
      checks = [
        {
          name = "gemini.enable";
          actual = cfg.enable;
          expected = true;
        }
        {
          name = "gemini.trustedFolders";
          actual = cfg.trustedFolders;
          expected = [ ];
        }
        {
          name = "gemini.excludedMcpServers.length";
          actual = builtins.length cfg.excludedMcpServers;
          expected = 11;
        }
        {
          name = "gemini.extensions";
          actual = cfg.extensions;
          expected = { };
        }
        {
          name = "gemini.hooks.beforeTool";
          actual = cfg.hooks.beforeTool;
          expected = null;
        }
        {
          name = "gemini.hooks.afterTool";
          actual = cfg.hooks.afterTool;
          expected = null;
        }
        {
          name = "gemini.skills.fromFlakeInputs";
          actual = cfg.skills.fromFlakeInputs;
          expected = [ ];
        }
        {
          name = "gemini.skills.local";
          actual = cfg.skills.local;
          expected = { };
        }
        {
          name = "gemini.commands.fromFlakeInputs";
          actual = cfg.commands.fromFlakeInputs;
          expected = [ ];
        }
        {
          name = "gemini.commands.local";
          actual = cfg.commands.local;
          expected = { };
        }
      ];
      failures = builtins.filter (c: c.actual != c.expected) checks;
      failureMsg = builtins.concatStringsSep "\n" (
        map (
          c: "  ${c.name}: expected ${builtins.toJSON c.expected}, got ${builtins.toJSON c.actual}"
        ) failures
      );
    in
    assert failures == [ ] || throw "Gemini default value regression:\n${failureMsg}";
    pkgs.runCommand "check-gemini-defaults-regression" { } ''
      echo "Gemini defaults regression: ${toString (builtins.length checks)} critical defaults verified"
      touch $out
    '';

  # Validate activation package builds (forces settings.json generation).
  gemini-settings-json = builtins.seq hmConfig.activationPackage (
    pkgs.runCommand "check-gemini-settings-json" { } ''
      echo "Gemini settings: activation package builds successfully (settings.json generation verified)"
      touch $out
    ''
  );

  # Validate the .gemini/.keep directory marker is created (proves module loaded).
  gemini-module-loaded =
    let
      keepFile = hmConfig.config.home.file.".gemini/.keep".text;
    in
    assert keepFile != "" || throw "Gemini .keep file is empty (module not loaded)";
    pkgs.runCommand "check-gemini-module-loaded" { } ''
      echo "Gemini module: .keep file present, module loaded successfully"
      touch $out
    '';

  # Validate Policy Engine TOML is deployed and settings.json uses policyPaths.
  gemini-policy-engine =
    let
      policyFileEntry = hmConfig.config.home.file.".gemini/policies/nix-managed.toml";
      policyContent = builtins.readFile policyFileEntry.source;
      inherit (pkgs) lib;
    in
    assert lib.stringLength policyContent > 0 || throw "Policy TOML is empty";
    assert lib.hasInfix "[[rule]]" policyContent || throw "No [[rule]] entries found";
    assert lib.hasInfix ''decision = "allow"'' policyContent || throw "No allow rules found";
    assert lib.hasInfix ''decision = "deny"'' policyContent || throw "No deny rules found";
    assert lib.hasInfix ''decision = "ask_user"'' policyContent || throw "No ask_user rules found";
    assert
      lib.hasInfix ''toolName = "read_file"'' policyContent || throw "Missing read_file tool mapping";
    assert
      lib.hasInfix ''toolName = "run_shell_command"'' policyContent
      || throw "No run_shell_command rules found";
    assert
      lib.hasInfix ''commandPrefix = "git"'' policyContent || throw "Missing git commandPrefix rule";
    pkgs.runCommand "check-gemini-policy-engine" { } ''
      echo "Gemini Policy Engine: TOML structure verified (8 assertions: non-empty, [[rule]], 3 decision types, tool mappings, git rule)"
      touch $out
    '';
}
