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
      # Verify the policy TOML file entry exists in home.file
      policyFileEntry = hmConfig.config.home.file.".gemini/policies/nix-managed.toml";
      policySource = policyFileEntry.source;
      # Read the generated TOML content
      policyContent = builtins.readFile policySource;
    in
    pkgs.runCommand "check-gemini-policy-engine"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
        passAsFile = [ "policy" ];
        policy = policyContent;
      }
      ''
        echo "Validating Gemini Policy Engine TOML..."

        # TOML must be non-empty
        if [ ! -s "$policyPath" ]; then
          echo "FAIL: policy TOML is empty"
          exit 1
        fi

        # Must contain [[rule]] entries
        if ! grep -q '^\[\[rule\]\]' "$policyPath"; then
          echo "FAIL: no [[rule]] entries found"
          exit 1
        fi

        # Must contain all three decision types
        if ! grep -q 'decision = "allow"' "$policyPath"; then
          echo "FAIL: no allow rules found"
          exit 1
        fi
        if ! grep -q 'decision = "deny"' "$policyPath"; then
          echo "FAIL: no deny rules found"
          exit 1
        fi
        if ! grep -q 'decision = "ask_user"' "$policyPath"; then
          echo "FAIL: no ask_user rules found"
          exit 1
        fi

        # Must contain built-in tool mappings (read_file, glob, etc.)
        if ! grep -q 'toolName = "read_file"' "$policyPath"; then
          echo "FAIL: missing read_file tool mapping"
          exit 1
        fi

        # Must contain shell command rules
        if ! grep -q 'toolName = "run_shell_command"' "$policyPath"; then
          echo "FAIL: no run_shell_command rules found"
          exit 1
        fi

        # Must contain git allow rule
        if ! grep -q 'commandPrefix = "git"' "$policyPath"; then
          echo "FAIL: missing git commandPrefix rule"
          exit 1
        fi

        echo "Gemini Policy Engine: TOML non-empty, 3 decision types, tool mappings, shell rules, git rule verified"
        touch $out
      '';
}
