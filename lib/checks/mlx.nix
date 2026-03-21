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
        "host"
        "huggingFaceHome"
        "maxNumSeqs"
        "port"
        "prefillBatchSize"
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
          expected = "mlx-community/Qwen3.5-122B-A10B-4bit";
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
          expected = null;
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

      # Conditional flags must NOT appear when their config values are null
      conditionalAbsent =
        (
          if mlxCfg.cacheMemoryMb == null then
            builtins.match ".*--cache-memory-mb.*" argsStr != null
          else
            false
        )
        || (
          if mlxCfg.prefillBatchSize == null then
            builtins.match ".*--prefill-batch-size.*" argsStr != null
          else
            false
        )
        || (
          if !mlxCfg.continuousBatching then
            builtins.match ".*--continuous-batching.*" argsStr != null
          else
            false
        )
        || (
          if mlxCfg.maxNumSeqs == null then builtins.match ".*--max-num-seqs.*" argsStr != null else false
        )
        || (
          if mlxCfg.chunkedPrefillTokens == null then
            builtins.match ".*--chunked-prefill-tokens.*" argsStr != null
          else
            false
        )
        || (
          if mlxCfg.completionBatchSize == null then
            builtins.match ".*--completion-batch-size.*" argsStr != null
          else
            false
        );
    in
    assert
      presentBanned == [ ]
      || throw "Banned vllm-mlx flags in ProgramArguments: ${builtins.toJSON presentBanned}";
    assert
      missingRequired == [ ]
      || throw "Missing required flags in ProgramArguments: ${builtins.toJSON missingRequired}";
    assert
      !conditionalAbsent
      || throw "Conditional flags present in ProgramArguments despite null config values";
    pkgs.runCommand "check-mlx-launchd" { } ''
      echo "MLX LaunchAgent: ${toString (builtins.length bannedFlags)} banned flags verified absent, ${toString (builtins.length requiredSubstrings)} required flags verified present, conditional flags verified"
      touch $out
    '';
}
