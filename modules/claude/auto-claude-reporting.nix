# Auto-Claude Reporting: Twice-Daily Digest and Real-Time Monitoring
#
# Scheduled reports and anomaly detection for auto-claude runs.
# Sends 8am and 5pm EST Slack reports with efficiency metrics.
# Alerts on anomalies: context exhaustion, stuck loops, failures.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;
  scriptDir = "${homeDir}/.claude/scripts";
  logDir = "${homeDir}/.claude/logs";

  # Python with required packages
  pythonWithDeps = pkgs.python3.withPackages (ps: [
    (ps.slack-sdk.overridePythonAttrs (_: {
      doCheck = false;
    }))
    ps.cryptography # Cryptographic recipes and primitives (system-wide requirement)
    ps.keyring
  ]);

  # Check if reporting is enabled
  reportingEnabled = cfg.autoClaude.reporting.enable;

  # Convert EST report times from config to UTC for launchd StartCalendarInterval
  # NOTE: This assumes EST is always UTC-5 and does NOT account for Daylight Saving Time (EDT).
  # During EDT (March-November), EST is actually UTC-4, so reports will be 1 hour off.
  # If you need DST-aware scheduling, consider using fixed UTC times or a more complex conversion.
  utcReportTimes = map (
    timeStr:
    let
      # Parse time string with regex to extract hour and minute
      match = builtins.match "0*([0-9]+):0*([0-9]+)" timeStr;
      hour = lib.toInt (builtins.elemAt match 0);
      minute = lib.toInt (builtins.elemAt match 1);
      # Assume EST = UTC-5 (not accounting for EDT which is UTC-4)
      utcHour = lib.mod (hour + 5) 24;
    in
    {
      Hour = utcHour;
      Minute = minute;
    }
  ) cfg.autoClaude.reporting.scheduledReports.times;

in
{
  options.programs.claude.autoClaude.reporting = {
    enable = lib.mkEnableOption "Auto-Claude reporting and monitoring" // {
      default = false;
    };

    scheduledReports = lib.mkOption {
      type = lib.types.submodule {
        options = {
          times = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "08:00"
              "17:00"
            ];
            description = "Times for scheduled reports in EST (HH:MM format). Default: 8am and 5pm EST.";
            example = [
              "08:00"
              "17:00"
            ];
          };

          slackChannel = lib.mkOption {
            type = lib.types.str;
            description = "Slack channel ID for scheduled reports (retrieved from BWS at runtime)";
            example = "C0AXXXXXXXX";
          };
        };
      };
      default = { };
      description = "Configuration for twice-daily digest reports";
    };

    alerts = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Real-time anomaly alerts" // {
            default = true;
          };

          contextThreshold = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 90;
            description = "Alert if context usage exceeds this percentage";
          };

          budgetThreshold = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 50;
            description = "Alert if run uses more than this percentage of token budget";
          };

          tokensNoOutput = lib.mkOption {
            type = lib.types.ints.positive;
            default = 50000;
            description = "Flag if tokens used exceeds this with no completed work units";
          };

          consecutiveFailures = lib.mkOption {
            type = lib.types.ints.positive;
            default = 2;
            description = "Alert after this many consecutive failures in same repo";
          };
        };
      };
      default = { };
      description = "Configuration for real-time anomaly detection and alerts";
    };
  };

  config = lib.mkIf reportingEnabled {
    home = {
      # Note: Python scripts (auto-claude-db.py, auto-claude-digest.py, auto-claude-monitor.py)
      # are now deployed unconditionally by auto-claude.nix, not here.
      # This prevents deployment conflicts when reporting is enabled.
      file = {
        "${logDir}/.gitkeep".text = "";
      };

      # Reminder to user: alert integration happens in auto-claude.sh
      # The monitor script is called after each run completes
      sessionVariables = {
        CLAUDE_MONITORING_ENABLED = lib.mkIf cfg.autoClaude.reporting.alerts.enable "1";
        CLAUDE_ALERT_CONTEXT_THRESHOLD = builtins.toString cfg.autoClaude.reporting.alerts.contextThreshold;
        CLAUDE_ALERT_BUDGET_THRESHOLD = builtins.toString cfg.autoClaude.reporting.alerts.budgetThreshold;
        CLAUDE_ALERT_TOKENS_NO_OUTPUT = builtins.toString cfg.autoClaude.reporting.alerts.tokensNoOutput;
        CLAUDE_ALERT_CONSECUTIVE_FAILURES = builtins.toString cfg.autoClaude.reporting.alerts.consecutiveFailures;
      };
    };

    # Launchd agent for scheduled digest reports
    # Runs at specified times each day (default: 8am and 5pm EST)
    launchd.agents."com.claude.auto-claude-digest" = {
      enable = true;
      config = {
        Label = "com.claude.auto-claude-digest";
        Program = "${pythonWithDeps}/bin/python3";
        ProgramArguments = [
          "${pythonWithDeps}/bin/python3"
          "${scriptDir}/auto-claude-digest.py"
          "--channel"
          cfg.autoClaude.reporting.scheduledReports.slackChannel
        ];

        # Run at configured times (UTC)
        StartCalendarInterval = utcReportTimes;

        # Standard launchd settings
        StandardOutPath = "${logDir}/launchd-digest.log";
        StandardErrorPath = "${logDir}/launchd-digest.err";

        # Inherit environment from shell
        EnvironmentVariables = {
          PATH = lib.concatStringsSep ":" [
            "${pythonWithDeps}/bin"
            "${pkgs.coreutils}/bin"
          ];
          HOME = homeDir;
        };

        # Run with reasonable settings
        ProcessType = "Standard";
        RunAtLoad = false;
      };
    };
  };
}
