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
    launchAgentLabel
    llamaSwapPkg
    llamaSwapConfigFile
    ;
in
{
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # LaunchAgent for Auto-Start
    # ==========================================================================
    # llama-swap proxy listens on the API port and manages vllm-mlx child
    # processes on ephemeral ports (startPort = 11436+). HardResourceLimits
    # is omitted — it would only cap the proxy process, not the vllm-mlx
    # children where the actual memory lives.
    launchd.agents.vllm-mlx = {
      enable = true;
      config = {
        Label = launchAgentLabel;
        ProgramArguments = [
          (lib.getExe llamaSwapPkg)
          "--config"
          "${llamaSwapConfigFile}"
          "--listen"
          "${cfg.host}:${toString cfg.port}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        # 2 min throttle — 70GB model loads take 20-60s, prevents rapid crash-restart loops (closes #256)
        ThrottleInterval = 120;
        # Background = Jetsam-eligible (applies to proxy; vllm-mlx children inherit separately).
        ProcessType = "Background";
        # Do not kill child vllm-mlx processes when launchd stops the proxy.
        AbandonProcessGroup = false;
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
