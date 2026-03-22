#
# MLX Module — LaunchAgent & Log Rotation
#
# macOS LaunchAgent configuration for the vllm-mlx inference server,
# plus newsyslog log rotation.
#
{
  config,
  lib,
  mlxShared,
  ...
}:
let
  inherit (mlxShared)
    cfg
    vllmMlxPkg
    launchAgentLabel
    ;
in
{
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # LaunchAgent for Auto-Start
    # ==========================================================================
    launchd.agents.vllm-mlx = {
      enable = true;
      config = {
        Label = launchAgentLabel;
        ProgramArguments = [
          (lib.getExe vllmMlxPkg)
          "serve"
          cfg.defaultModel
          "--port"
          (toString cfg.port)
          "--host"
          cfg.host
        ]
        ++ lib.optionals (cfg.cacheMemoryMb != null) [
          "--cache-memory-mb"
          (toString cfg.cacheMemoryMb)
        ]
        ++ lib.optionals (cfg.prefillBatchSize != null) [
          "--prefill-batch-size"
          (toString cfg.prefillBatchSize)
        ]
        ++ lib.optionals cfg.continuousBatching [
          "--continuous-batching"
        ]
        ++ lib.optionals (cfg.maxNumSeqs != null) [
          "--max-num-seqs"
          (toString cfg.maxNumSeqs)
        ]
        ++ lib.optionals (cfg.chunkedPrefillTokens != null) [
          "--chunked-prefill-tokens"
          (toString cfg.chunkedPrefillTokens)
        ]
        ++ lib.optionals (cfg.completionBatchSize != null) [
          "--completion-batch-size"
          (toString cfg.completionBatchSize)
        ]
        ++ lib.optionals cfg.enableAutoToolChoice [
          "--enable-auto-tool-choice"
        ]
        ++ lib.optionals (cfg.enableAutoToolChoice && cfg.toolCallParser != null) [
          "--tool-call-parser"
          cfg.toolCallParser
        ]
        ++ lib.optionals (cfg.reasoningParser != null) [
          "--reasoning-parser"
          cfg.reasoningParser
        ];
        RunAtLoad = true;
        KeepAlive = true;
        # 2 min throttle — 70GB model loads take 20-60s, prevents rapid crash-restart loops (closes #256)
        ThrottleInterval = 120;
        # OOM prevention: Background = Jetsam-eligible; hard RSS ceiling enforced by kernel.
        ProcessType = "Background";
        HardResourceLimits = {
          ResidentSetSize = cfg.memoryHardLimitGb * 1073741824;
        };
        EnvironmentVariables = {
          HF_HOME = cfg.huggingFaceHome;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.error.log";
      };
    };

    # ==========================================================================
    # Log Rotation (closes #255)
    # ==========================================================================
    # newsyslog rotates logs when they exceed 10MB, keeping 3 compressed archives.
    # Stock macOS newsyslog only reads /etc/newsyslog.d/ (requires root), so a
    # companion LaunchAgent invokes it hourly with our user-level config.
    home.file.".config/newsyslog.d/vllm-mlx.conf".text = ''
      # logfilename                                                                [owner:group]  mode  count  size  when  flags
      ${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.error.log        :              644   3      10240 *     J
      ${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.log              :              644   3      10240 *     J
    '';

    launchd.agents.vllm-mlx-logrotate = {
      enable = true;
      config = {
        Label = "dev.vllm-mlx.logrotate";
        ProgramArguments = [
          "/usr/sbin/newsyslog"
          "-f"
          "${config.home.homeDirectory}/.config/newsyslog.d/vllm-mlx.conf"
        ];
        StartCalendarInterval = [ { Minute = 0; } ]; # hourly
      };
    };
  };
}
