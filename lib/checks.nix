# Nix quality checks - single source of truth for pre-commit and CI
{
  pkgs,
  src,
  home-manager,
  aiModule,
}:
let
  # Shared test module configuration — used by module-eval and regression checks
  hmConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      aiModule
      {
        _module.args.userConfig = {
          ai.claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
        };
        home = {
          username = "test-user";
          homeDirectory = "/home/test-user";
          stateVersion = "25.11";
        };
      }
    ];
  };
in
{
  formatting = pkgs.runCommand "check-formatting" { } ''
    cp -r ${src} $TMPDIR/src
    chmod -R u+w $TMPDIR/src
    cd $TMPDIR/src
    ${pkgs.lib.getExe pkgs.nixfmt-tree} --fail-on-change --no-cache --tree-root $TMPDIR/src .
    touch $out
  '';

  statix = pkgs.runCommand "check-statix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.statix} check .
    touch $out
  '';

  deadnix = pkgs.runCommand "check-deadnix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.deadnix} -L --fail .
    touch $out
  '';

  # Lint shell scripts with shellcheck
  # Catches common bugs: unquoted variables, undefined vars, useless use of cat, etc.
  # Excludes .git directories and nix store paths
  # --severity=warning: Only fail on warning/error level (not info style suggestions)
  # SC1091: Exclude "not following" errors for external sources (can't resolve in Nix sandbox)
  # Excludes zsh scripts (shellcheck only supports sh/bash/dash/ksh)
  # Uses find with -print0 and xargs -0 for robustness with filenames containing spaces and special characters
  shellcheck = pkgs.runCommand "check-shellcheck" { } ''
    cd ${src}
    find . -name "*.sh" -not -path "./.git/*" -not -path "./result/*" -print0 | \
    xargs -0 bash -c '
      for script in "$@"; do
        # Skip zsh scripts (shellcheck does not support them)
        if head -1 "$script" | grep -q "zsh"; then
          echo "Skipping zsh script: $script"
        else
          echo "Checking $script..."
          ${pkgs.lib.getExe pkgs.shellcheck} --severity=warning --exclude=SC1091 "$script"
        fi
      done
    ' bash
    touch $out
  '';

  # Evaluate the real home-manager module with real inputs to catch import errors
  module-eval = builtins.seq hmConfig.activationPackage (
    pkgs.runCommand "check-module-eval" { } ''
      touch $out
    ''
  );

  # ============================================================================
  # Regression Tests
  # ============================================================================

  # Verify all expected option paths exist in the evaluated module.
  # Catches accidentally dropped options (e.g., from refactoring with lib;).
  options-regression =
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
    '';

  # Verify evaluated config values match expected values.
  # Tests the FULL module output (options.nix defaults + claude-config.nix overrides).
  # Catches unintended changes to either file.
  defaults-regression =
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
    '';

  # Validate the pure settings JSON generator (lib/claude-settings.nix).
  # Verifies structure, required keys, types, and value correctness.
  settings-json =
    let
      ciSettings = import ./claude-settings.nix {
        inherit (pkgs) lib;
        homeDir = "/home/test-user";
        schemaUrl = "https://json.schemastore.org/claude-code-settings.json";
        permissions = {
          allow = [
            "Read"
            "Write"
          ];
          deny = [ "Bash(rm -rf /)" ];
          ask = [ ];
        };
        plugins = {
          marketplaces = { };
          enabledPlugins = { };
        };
      };
    in
    pkgs.runCommand "check-settings-json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        passAsFile = [ "json" ];
        json = builtins.toJSON ciSettings;
      }
      ''
        echo "Validating settings JSON structure..."

        # Verify required keys exist
        jq -e 'has("$schema")' "$jsonPath" > /dev/null || { echo "FAIL: missing \$schema"; exit 1; }
        jq -e 'has("alwaysThinkingEnabled")' "$jsonPath" > /dev/null || { echo "FAIL: missing alwaysThinkingEnabled"; exit 1; }
        jq -e 'has("permissions")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions"; exit 1; }
        jq -e 'has("extraKnownMarketplaces")' "$jsonPath" > /dev/null || { echo "FAIL: missing extraKnownMarketplaces"; exit 1; }
        jq -e 'has("enabledPlugins")' "$jsonPath" > /dev/null || { echo "FAIL: missing enabledPlugins"; exit 1; }
        jq -e 'has("statusLine")' "$jsonPath" > /dev/null || { echo "FAIL: missing statusLine"; exit 1; }

        # Verify permission structure
        jq -e '.permissions | has("allow")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.allow"; exit 1; }
        jq -e '.permissions | has("deny")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.deny"; exit 1; }
        jq -e '.permissions | has("ask")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.ask"; exit 1; }
        jq -e '.permissions | has("additionalDirectories")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.additionalDirectories"; exit 1; }

        # Verify types
        jq -e '.alwaysThinkingEnabled | type == "boolean"' "$jsonPath" > /dev/null || { echo "FAIL: alwaysThinkingEnabled not boolean"; exit 1; }
        jq -e '.permissions.allow | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.allow not array"; exit 1; }
        jq -e '.permissions.deny | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.deny not array"; exit 1; }
        jq -e '.permissions.ask | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.ask not array"; exit 1; }
        jq -e '.permissions.additionalDirectories | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: additionalDirectories not array"; exit 1; }
        jq -e '.statusLine | type == "object"' "$jsonPath" > /dev/null || { echo "FAIL: statusLine not object"; exit 1; }
        jq -e '.extraKnownMarketplaces | type == "object"' "$jsonPath" > /dev/null || { echo "FAIL: extraKnownMarketplaces not object"; exit 1; }

        # Verify values
        jq -e '."$schema" == "https://json.schemastore.org/claude-code-settings.json"' "$jsonPath" > /dev/null || { echo "FAIL: wrong schema URL"; exit 1; }
        jq -e '.alwaysThinkingEnabled == true' "$jsonPath" > /dev/null || { echo "FAIL: alwaysThinkingEnabled should be true"; exit 1; }
        jq -e '.permissions.allow | length == 2' "$jsonPath" > /dev/null || { echo "FAIL: expected 2 allow entries"; exit 1; }
        jq -e '.permissions.deny | length == 1' "$jsonPath" > /dev/null || { echo "FAIL: expected 1 deny entry"; exit 1; }
        jq -e '.permissions.ask | length == 0' "$jsonPath" > /dev/null || { echo "FAIL: expected 0 ask entries"; exit 1; }
        jq -e '.statusLine.type == "command"' "$jsonPath" > /dev/null || { echo "FAIL: statusLine.type should be command"; exit 1; }

        echo "Settings JSON: 6 keys, 5 permission fields, 6 type checks, 6 value checks passed"
        touch $out
      '';

  # ============================================================================
  # MLX Module Regression Tests
  # ============================================================================

  # Verify all expected MLX option paths exist, including nested backend settings.
  mlx-options-regression =
    let
      mlxOpts = hmConfig.config.programs.mlx;

      expectedTopLevel = [
        "backend"
        "defaultModel"
        "enable"
        "host"
        "huggingFaceHome"
        "mlxLmSettings"
        "port"
        "vllmMlxSettings"
      ];
      actualTopLevel = builtins.attrNames mlxOpts;
      missingTopLevel = builtins.filter (o: !(builtins.elem o actualTopLevel)) expectedTopLevel;

      expectedVllmMlx = [
        "cacheMemoryMb"
        "chunkedPrefillTokens"
        "prefixCacheSize"
      ];
      actualVllmMlx = builtins.attrNames mlxOpts.vllmMlxSettings;
      missingVllmMlx = builtins.filter (o: !(builtins.elem o actualVllmMlx)) expectedVllmMlx;

      expectedMlxLm = [
        "decodeConcurrency"
        "prefillStepSize"
        "promptCacheBytes"
        "promptCacheSize"
        "promptConcurrency"
      ];
      actualMlxLm = builtins.attrNames mlxOpts.mlxLmSettings;
      missingMlxLm = builtins.filter (o: !(builtins.elem o actualMlxLm)) expectedMlxLm;
    in
    assert
      missingTopLevel == [ ] || throw "Missing MLX top-level options: ${builtins.toJSON missingTopLevel}";
    assert
      missingVllmMlx == [ ]
      || throw "Missing MLX vllmMlxSettings options: ${builtins.toJSON missingVllmMlx}";
    assert
      missingMlxLm == [ ] || throw "Missing MLX mlxLmSettings options: ${builtins.toJSON missingMlxLm}";
    pkgs.runCommand "check-mlx-options-regression" { } ''
      echo "MLX option regression: ${toString (builtins.length expectedTopLevel)} top-level, ${toString (builtins.length expectedVllmMlx)} vllm-mlx, ${toString (builtins.length expectedMlxLm)} mlx-lm options verified"
      touch $out
    '';

  # Verify MLX evaluated config values match expected defaults.
  mlx-defaults-regression =
    let
      mlxCfg = hmConfig.config.programs.mlx;
      checks = [
        {
          name = "mlx.enable";
          actual = mlxCfg.enable;
          expected = true;
        }
        {
          name = "mlx.backend";
          actual = mlxCfg.backend;
          expected = "vllm-mlx";
        }
        {
          name = "mlx.defaultModel";
          actual = mlxCfg.defaultModel;
          expected = "mlx-community/Qwen3.5-122B-A10B-4bit";
        }
        {
          name = "mlx.port";
          actual = mlxCfg.port;
          expected = 11434;
        }
        {
          name = "mlx.vllmMlxSettings.chunkedPrefillTokens";
          actual = mlxCfg.vllmMlxSettings.chunkedPrefillTokens;
          expected = 8192;
        }
        {
          name = "mlx.vllmMlxSettings.cacheMemoryMb";
          actual = mlxCfg.vllmMlxSettings.cacheMemoryMb;
          expected = null;
        }
        {
          name = "mlx.vllmMlxSettings.prefixCacheSize";
          actual = mlxCfg.vllmMlxSettings.prefixCacheSize;
          expected = null;
        }
        {
          name = "mlx.mlxLmSettings.prefillStepSize";
          actual = mlxCfg.mlxLmSettings.prefillStepSize;
          expected = 8192;
        }
        {
          name = "mlx.mlxLmSettings.promptCacheSize";
          actual = mlxCfg.mlxLmSettings.promptCacheSize;
          expected = null;
        }
        {
          name = "mlx.mlxLmSettings.promptCacheBytes";
          actual = mlxCfg.mlxLmSettings.promptCacheBytes;
          expected = null;
        }
        {
          name = "mlx.mlxLmSettings.decodeConcurrency";
          actual = mlxCfg.mlxLmSettings.decodeConcurrency;
          expected = null;
        }
        {
          name = "mlx.mlxLmSettings.promptConcurrency";
          actual = mlxCfg.mlxLmSettings.promptConcurrency;
          expected = null;
        }
      ];
      failures = builtins.filter (c: c.actual != c.expected) checks;
      failureMsg = builtins.concatStringsSep "\n" (
        map (
          c: "  ${c.name}: expected ${builtins.toJSON c.expected}, got ${builtins.toJSON c.actual}"
        ) failures
      );
    in
    assert failures == [ ] || throw "MLX default value regression:\n${failureMsg}";
    pkgs.runCommand "check-mlx-defaults-regression" { } ''
      echo "MLX defaults regression: ${toString (builtins.length checks)} critical defaults verified"
      touch $out
    '';

  # CLI flag allowlist validation — catches invalid flags before they crash the server.
  # This is the guard that would have caught the original bug (mlx-lm flags on vllm-mlx).
  mlx-cli-flags =
    let
      agentConfig = hmConfig.config.launchd.agents.vllm-mlx.config;
      progArgs = agentConfig.ProgramArguments;

      # Valid flags from vllm-mlx==0.2.6 --help output.
      # IMPORTANT: Update this list when changing pinned versions in modules/mlx/default.nix.
      validVllmMlxFlags = [
        "--api-key"
        "--cache-memory-mb"
        "--cache-memory-percent"
        "--chunked-prefill-tokens"
        "--completion-batch-size"
        "--continuous-batching"
        "--default-temperature"
        "--default-top-p"
        "--disable-prefix-cache"
        "--embedding-model"
        "--enable-auto-tool-choice"
        "--enable-prefix-cache"
        "--host"
        "--max-cache-blocks"
        "--max-num-seqs"
        "--max-tokens"
        "--mcp-config"
        "--no-memory-aware-cache"
        "--paged-cache-block-size"
        "--port"
        "--prefix-cache-size"
        "--prefill-batch-size"
        "--rate-limit"
        "--reasoning-parser"
        "--stream-interval"
        "--timeout"
        "--tool-call-parser"
        "--use-paged-cache"
      ];

      # Valid flags from mlx-lm==0.31.1 mlx_lm.server --help output.
      # IMPORTANT: Update this list when changing pinned versions in modules/mlx/default.nix.
      validMlxLmFlags = [
        "--adapter-path"
        "--chat-template"
        "--chat-template-args"
        "--decode-concurrency"
        "--draft-model"
        "--host"
        "--log-level"
        "--max-tokens"
        "--min-p"
        "--model"
        "--num-draft-tokens"
        "--pipeline"
        "--port"
        "--prefill-step-size"
        "--prompt-cache-bytes"
        "--prompt-cache-size"
        "--prompt-concurrency"
        "--temp"
        "--top-k"
        "--top-p"
        "--trust-remote-code"
        "--use-default-chat-template"
      ];

      validFlags =
        if hmConfig.config.programs.mlx.backend == "vllm-mlx" then validVllmMlxFlags else validMlxLmFlags;

      usedFlags = builtins.filter (a: builtins.substring 0 2 a == "--") progArgs;
      invalidFlags = builtins.filter (f: !(builtins.elem f validFlags)) usedFlags;
    in
    assert
      invalidFlags == [ ]
      || throw "MLX LaunchAgent uses invalid ${hmConfig.config.programs.mlx.backend} flags: ${builtins.toJSON invalidFlags}";
    pkgs.runCommand "check-mlx-cli-flags" { } ''
      echo "MLX CLI flags: ${toString (builtins.length usedFlags)} flags validated against ${hmConfig.config.programs.mlx.backend} allowlist"
      touch $out
    '';

  # Validate the maestro-cli script extraction produces correct output.
  # Builds the script via pkgs.substituteAll and verifies content integrity.
  maestro-script =
    let
      testScript = pkgs.replaceVars ../modules/maestro/scripts/maestro-cli.sh {
        maestroApp = "/test/path/to/Maestro";
      };
    in
    pkgs.runCommand "check-maestro-script" { } ''
      echo "Validating maestro-cli script..."

      # Verify @maestroApp@ placeholder was substituted
      if grep -q "@maestroApp@" ${testScript}; then
        echo "FAIL: @maestroApp@ placeholder was NOT substituted"
        exit 1
      fi

      # Verify the test path appears in the script
      if ! grep -q "/test/path/to/Maestro" ${testScript}; then
        echo "FAIL: substituted path not found in script"
        exit 1
      fi

      # Verify shebang
      if ! head -1 ${testScript} | grep -q "#!/usr/bin/env bash"; then
        echo "FAIL: missing or incorrect shebang"
        exit 1
      fi

      # Verify strict mode
      if ! grep -q "set -euo pipefail" ${testScript}; then
        echo "FAIL: missing set -euo pipefail"
        exit 1
      fi

      # Verify exec command is present
      if ! grep -q 'exec.*MAESTRO_APP' ${testScript}; then
        echo "FAIL: missing exec command"
        exit 1
      fi

      # Verify error handling exists
      if ! grep -q 'Maestro not found' ${testScript}; then
        echo "FAIL: missing error message"
        exit 1
      fi

      echo "Maestro script: substitution, shebang, strict mode, exec, error handling verified"
      touch $out
    '';
}
