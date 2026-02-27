# Auto-Claude: Scheduled Autonomous Maintenance
#
# Configures launchd agents to run Claude autonomously on git repositories
# at scheduled times. Uses the apiKeyHelper for headless authentication.
# Sends rich Slack notifications via Python notifier.
#
# Options defined in: auto-claude/options.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;
  scriptPath = "${homeDir}/.claude/scripts/auto-claude.sh";
  logDir = "${homeDir}/.claude/logs";

  # Python environment for auto-claude scripts
  pythonEnv = pkgs.python3.withPackages (ps: [
    (ps.slack-sdk.overridePythonAttrs (_: {
      doCheck = false; # Disable tests - they fail in CI with connection/signal errors
    }))
    ps.cryptography # Cryptographic recipes and primitives (system-wide requirement)
    ps.keyring # macOS Keychain access
    ps.pyyaml
  ]);

  # Convert time spec to launchd calendar interval
  # Supports both simple hour (int) and {hour, minute} attrset
  mkCalendarInterval =
    time:
    if builtins.isInt time then
      {
        Hour = time;
        Minute = 0;
      }
    else
      {
        Hour = time.hour;
        Minute = time.minute or 0;
      };

  # Normalize schedule settings (supports single hour, list of hours, or list of times)
  getScheduleTimes =
    schedule:
    let
      timesList = schedule.times;
      hoursList = schedule.hours;
      hourOpt = schedule.hour;
    in
    if timesList != [ ] then
      timesList
    else if hoursList != [ ] then
      hoursList
    else if hourOpt != null then
      [ hourOpt ]
    else
      [ ];

  # Filter to only enabled repositories
  enabledRepos = lib.filterAttrs (_: r: r.enabled) cfg.autoClaude.repositories;

in
{
  imports = [ ./auto-claude/options.nix ];

  config = lib.mkIf (cfg.enable && cfg.autoClaude.enable) {
    # Ensure each enabled repository has at least one scheduled time
    assertions = lib.mapAttrsToList (
      name: repoCfg:
      let
        timesList = getScheduleTimes repoCfg.schedule;
      in
      {
        assertion = (!repoCfg.enabled) || (timesList != [ ]);
        message = "programs.claude.autoClaude.repositories.${name} must set schedule.times when enabled";
      }
    ) enabledRepos;

    # Warn if apiKeyHelper is not enabled (required for headless auth)
    warnings = lib.optional (!cfg.apiKeyHelper.enable) ''
      programs.claude.autoClaude is enabled but programs.claude.apiKeyHelper is not.
      Auto-Claude requires apiKeyHelper for headless authentication.
      Enable it with: programs.claude.apiKeyHelper.enable = true;
    '';

    # Add Python with slack-sdk to path and deploy scripts
    home = {
      packages = [ pythonEnv ];

      file = {
        # Deploy shell script
        ".claude/scripts/auto-claude.sh" = {
          source = ./auto-claude.sh;
          executable = true;
        };

        # Deploy control script for runtime pause/resume/status
        ".claude/scripts/auto-claude-ctl.sh" = {
          source = ./auto-claude-ctl.sh;
          executable = true;
        };

        # Deploy orchestrator prompt
        ".claude/scripts/orchestrator-prompt.txt" = {
          source = ./orchestrator-prompt.txt;
        };

        # Deploy Python notifier
        ".claude/scripts/auto-claude-notify.py" = {
          source = ./auto-claude-notify.py;
          executable = true;
        };

        # Deploy BWS helper (shared by notifier and API key helper)
        ".claude/scripts/bws_helper.py" = {
          source = ./bws_helper.py;
          executable = true;
        };

        # Deploy Python modules for auto-claude
        ".claude/scripts/auto_claude_utils.py" = {
          source = ./auto_claude_utils.py;
          executable = true;
        };
        ".claude/scripts/auto_claude_preflight.py" = {
          source = ./auto_claude_preflight.py;
          executable = true;
        };
        ".claude/scripts/auto_claude_postrun.py" = {
          source = ./auto_claude_postrun.py;
          executable = true;
        };

        # Deploy Slack notification test script
        ".claude/scripts/test-slack-notifications.py" = {
          source = ./test-slack-notifications.py;
          executable = true;
        };

        # Deploy monitoring and reporting modules (always deployed, not gated by reporting.enable)
        # These are dependencies of auto-claude-monitor.py which runs after each auto-claude run
        ".claude/scripts/auto_claude_db.py" = {
          source = ./auto_claude_db.py;
          executable = true;
        };
        ".claude/scripts/auto-claude-monitor.py" = {
          source = ./auto-claude-monitor.py;
          executable = true;
        };
        ".claude/scripts/auto-claude-digest.py" = {
          source = ./auto-claude-digest.py;
          executable = true;
        };

        # Deploy BWS config template (user copies to .env and fills in values)
        ".config/bws/.env.example" = {
          source = ./bws-env.example;
        };
      };

      # Shell alias for convenient access to control script
      shellAliases = {
        auto-claude-ctl = "${homeDir}/.claude/scripts/auto-claude-ctl.sh";
      };
    };

    # Add shell alias for convenience
    programs.zsh.shellAliases = {
      auto-claude-ctl = "${homeDir}/.claude/scripts/auto-claude-ctl.sh";
    };

    # Create launchd agents for each repository (Darwin only)
    # Each agent calls the same script with repository-specific arguments
    launchd.agents = lib.mapAttrs' (
      name: repoCfg:
      let
        timesList = getScheduleTimes repoCfg.schedule;
        slackArg = if repoCfg.slackChannel != null then repoCfg.slackChannel else "";
      in
      lib.nameValuePair "com.claude.auto-claude-${name}" {
        enable = repoCfg.enabled;
        config = {
          Label = "com.claude.auto-claude-${name}";
          # Link to Ghostty for TCC permission inheritance
          # Agents associated with an app can inherit its Full Disk Access
          AssociatedBundleIdentifiers = [ "com.mitchellh.ghostty" ];
          # Pass arguments at runtime instead of baking them into the script
          ProgramArguments = [
            scriptPath
            repoCfg.path
            (toString repoCfg.maxBudget)
            logDir
            slackArg
          ];
          StartCalendarInterval = map mkCalendarInterval timesList;
          StandardOutPath = "${logDir}/launchd-${name}.log";
          StandardErrorPath = "${logDir}/launchd-${name}.err";
          EnvironmentVariables = {
            HOME = homeDir;
            # Claude model selection (defense-in-depth: env var + settings.json + --model flag)
            CLAUDE_MODEL = repoCfg.model;
            # Use per-user profile path and pythonEnv for proper package resolution
            # pythonEnv contains slack-sdk and other required packages
            PATH = "${pythonEnv}/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";
            # Explicitly set PYTHONPATH for launchd's clean environment
            # Nix python wrappers may not resolve properly without this
            # Include scripts directory for auto_claude_db, auto_claude_utils, etc.
            PYTHONPATH = "${pythonEnv}/${pkgs.python3.sitePackages}:${homeDir}/.claude/scripts";
            # GitHub CLI config directory for headless authentication
            # gh will use the token from ~/.config/gh/hosts.yml
            GH_CONFIG_DIR = "${homeDir}/.config/gh";
          }
          # API key helper for headless Claude authentication
          # Must be passed to launchd environment, not just settings.json
          // lib.optionalAttrs cfg.apiKeyHelper.enable {
            API_KEY_HELPER = "${homeDir}/${cfg.apiKeyHelper.scriptPath}";
          };
        };
      }
    ) enabledRepos;
  };
}
