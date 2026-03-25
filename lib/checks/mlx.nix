# MLX module regression tests and LaunchAgent validation (vllm-mlx 0.2.6)
{ pkgs, hmConfig }:
let
  mlxCfg = hmConfig.config.programs.mlx;
in
{
  # Verify all expected MLX option paths exist.
  # Flat structure — no nested backend settings (vllm-mlx only since v0.2.6).
  mlx-options-regression =
    let
      expectedOptions = [
        "cacheMemoryMb"
        "chunkedPrefillTokens"
        "completionBatchSize"
        "continuousBatching"
        "defaultModel"
        "enable"
        "enableAutoToolChoice"
        "host"
        "huggingFaceHome"
        "maxNumSeqs"
        "memoryHardLimitGb"
        "port"
        "prefillBatchSize"
        "reasoningParser"
        "toolCallParser"
      ];
      actualOptions = builtins.attrNames mlxCfg;
      missingOptions = builtins.filter (o: !(builtins.elem o actualOptions)) expectedOptions;
    in
    assert missingOptions == [ ] || throw "Missing MLX options: ${builtins.toJSON missingOptions}";
    pkgs.runCommand "check-mlx-options-regression" { } ''
      echo "MLX option regression: ${toString (builtins.length expectedOptions)} options verified"
      touch $out
    '';

  # Verify MLX evaluated config values match expected defaults.
  mlx-defaults-regression =
    let
      checks = [
        {
          name = "mlx.enable";
          actual = mlxCfg.enable;
          expected = true;
        }
        {
          name = "mlx.defaultModel";
          actual = mlxCfg.defaultModel;
          expected = "mlx-community/Qwen3.5-27B-4bit";
        }
        {
          name = "mlx.port";
          actual = mlxCfg.port;
          expected = 11434;
        }
        {
          name = "mlx.host";
          actual = mlxCfg.host;
          expected = "127.0.0.1";
        }
        {
          name = "mlx.huggingFaceHome";
          actual = mlxCfg.huggingFaceHome;
          expected = "/Volumes/HuggingFace";
        }
        {
          name = "mlx.cacheMemoryMb";
          actual = mlxCfg.cacheMemoryMb;
          expected = 16384;
        }
        {
          name = "mlx.prefillBatchSize";
          actual = mlxCfg.prefillBatchSize;
          expected = null;
        }
        {
          name = "mlx.continuousBatching";
          actual = mlxCfg.continuousBatching;
          expected = false;
        }
        {
          name = "mlx.maxNumSeqs";
          actual = mlxCfg.maxNumSeqs;
          expected = null;
        }
        {
          name = "mlx.chunkedPrefillTokens";
          actual = mlxCfg.chunkedPrefillTokens;
          expected = null;
        }
        {
          name = "mlx.completionBatchSize";
          actual = mlxCfg.completionBatchSize;
          expected = null;
        }
        {
          name = "mlx.memoryHardLimitGb";
          actual = mlxCfg.memoryHardLimitGb;
          expected = 100;
        }
        {
          name = "mlx.enableAutoToolChoice";
          actual = mlxCfg.enableAutoToolChoice;
          expected = true;
        }
        {
          name = "mlx.toolCallParser";
          actual = mlxCfg.toolCallParser;
          expected = "auto";
        }
        {
          name = "mlx.reasoningParser";
          actual = mlxCfg.reasoningParser;
          expected = "qwen3";
        }
        # Environment variables
        {
          name = "mlx.env.MLX_API_URL";
          actual = hmConfig.config.home.sessionVariables.MLX_API_URL;
          expected = "http://127.0.0.1:11434/v1";
        }
        {
          name = "mlx.env.MLX_PORT";
          actual = hmConfig.config.home.sessionVariables.MLX_PORT;
          expected = "11434";
        }
        {
          name = "mlx.env.MLX_HOST";
          actual = hmConfig.config.home.sessionVariables.MLX_HOST;
          expected = "127.0.0.1";
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

  # Validate MLX LaunchAgent ProgramArguments contain no banned flags,
  # include all required flags, and respect conditional flag logic.
  # This catches the exact class of bug that caused the vllm-mlx crash-loop.
  mlx-launchd =
    let
      launchdCfg = hmConfig.config.launchd.agents.vllm-mlx.config;
      args = launchdCfg.ProgramArguments;
      argsStr = builtins.concatStringsSep " " args;

      # Flags removed in vllm-mlx v0.2.6 — must NEVER appear
      bannedFlags = [
        "--max-kv-size"
        "--prefill-step-size"
        "--prompt-cache-size"
        "--decode-concurrency"
        "--prompt-concurrency"
        "--draft-model"
        "--num-draft-tokens"
        "--pipeline"
      ];
      presentBanned = builtins.filter (f: builtins.match ".*${f}.*" argsStr != null) bannedFlags;

      # Core flags that must always be present
      requiredSubstrings = [
        "serve"
        "--port"
        "--host"
      ];
      missingRequired = builtins.filter (f: builtins.match ".*${f}.*" argsStr == null) requiredSubstrings;

      # Conditional flags must NOT appear when their config value is null/false.
      # Data-driven: list of { flag, shouldBeAbsent } — matches bannedFlags pattern above.
      conditionalChecks = [
        {
          flag = "--cache-memory-mb";
          shouldBeAbsent = mlxCfg.cacheMemoryMb == null;
        }
        {
          flag = "--prefill-batch-size";
          shouldBeAbsent = mlxCfg.prefillBatchSize == null;
        }
        {
          flag = "--continuous-batching";
          shouldBeAbsent = !mlxCfg.continuousBatching;
        }
        {
          flag = "--max-num-seqs";
          shouldBeAbsent = mlxCfg.maxNumSeqs == null;
        }
        {
          flag = "--chunked-prefill-tokens";
          shouldBeAbsent = mlxCfg.chunkedPrefillTokens == null;
        }
        {
          flag = "--completion-batch-size";
          shouldBeAbsent = mlxCfg.completionBatchSize == null;
        }
        {
          flag = "--enable-auto-tool-choice";
          shouldBeAbsent = !mlxCfg.enableAutoToolChoice;
        }
        {
          flag = "--tool-call-parser";
          shouldBeAbsent = mlxCfg.toolCallParser == null || !mlxCfg.enableAutoToolChoice;
        }
        {
          flag = "--reasoning-parser";
          shouldBeAbsent = mlxCfg.reasoningParser == null;
        }
      ];
      conditionalViolations = builtins.filter (
        c: c.shouldBeAbsent && builtins.match ".*${c.flag}.*" argsStr != null
      ) conditionalChecks;
    in
    assert
      presentBanned == [ ]
      || throw "Banned vllm-mlx flags in ProgramArguments: ${builtins.toJSON presentBanned}";
    assert
      missingRequired == [ ]
      || throw "Missing required flags in ProgramArguments: ${builtins.toJSON missingRequired}";
    assert
      conditionalViolations == [ ]
      || throw "Conditional flags present despite null/false config: ${
        builtins.toJSON (map (c: c.flag) conditionalViolations)
      }";
    pkgs.runCommand "check-mlx-launchd" { } ''
      echo "MLX LaunchAgent: ${toString (builtins.length bannedFlags)} banned flags verified absent, ${toString (builtins.length requiredSubstrings)} required flags verified present, conditional flags verified"
      touch $out
    '';

  # Verify OOM prevention: ProcessType + HardResourceLimits in LaunchAgent.
  mlx-launchd-memory-safety =
    let
      launchdCfg = hmConfig.config.launchd.agents.vllm-mlx.config;
    in
    assert
      launchdCfg.ProcessType == "Background"
      || throw "ProcessType must be \"Background\" for Jetsam eligibility";
    assert
      launchdCfg.HardResourceLimits.ResidentSetSize > 0
      || throw "HardResourceLimits.ResidentSetSize must be positive";
    pkgs.runCommand "check-mlx-launchd-memory-safety" { } ''
      echo "MLX LaunchAgent memory safety: ProcessType=Background, hard=${toString mlxCfg.memoryHardLimitGb}GB verified"
      touch $out
    '';

  # Negative test: verify the banned-flag detection logic actually catches bad flags.
  # Without this, a regex typo in mlx-launchd could silently pass banned flags through.
  mlx-launchd-negative =
    let
      # Synthetic args strings containing banned flags — each MUST be detected
      testCases = [
        {
          input = "serve model --max-kv-size 1024 --port 11434";
          bannedFlag = "--max-kv-size";
        }
        {
          input = "serve model --prefill-step-size 256 --port 11434";
          bannedFlag = "--prefill-step-size";
        }
        {
          input = "serve model --prompt-cache-size 512 --port 11434";
          bannedFlag = "--prompt-cache-size";
        }
        {
          input = "serve model --decode-concurrency 4 --port 11434";
          bannedFlag = "--decode-concurrency";
        }
        {
          input = "serve model --prompt-concurrency 2 --port 11434";
          bannedFlag = "--prompt-concurrency";
        }
        {
          input = "serve model --draft-model foo --port 11434";
          bannedFlag = "--draft-model";
        }
        {
          input = "serve model --num-draft-tokens 8 --port 11434";
          bannedFlag = "--num-draft-tokens";
        }
        {
          input = "serve model --pipeline parallel --port 11434";
          bannedFlag = "--pipeline";
        }
      ];
      # Same detection logic as mlx-launchd — if this changes there, it must change here
      detect = flag: str: builtins.match ".*${flag}.*" str != null;
      # Every banned flag must be detected
      undetected = builtins.filter (tc: !(detect tc.bannedFlag tc.input)) testCases;
    in
    assert
      undetected == [ ]
      || throw "Negative test failed — banned flags NOT detected: ${
        builtins.toJSON (map (tc: tc.bannedFlag) undetected)
      }";
    pkgs.runCommand "check-mlx-launchd-negative" { } ''
      echo "MLX LaunchAgent negative: ${toString (builtins.length testCases)} banned flag patterns verified detectable"
      touch $out
    '';
}
