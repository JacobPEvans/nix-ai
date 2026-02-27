# Maestro Auto Run Home-Manager Module
#
# Deploys Maestro Auto Run playbooks and configures scheduled execution.
# Uses maestro-cli to execute playbooks via launchd agents.
#
# Architecture:
# - Playbooks deployed to ~/Maestro/Auto Run Docs/<playbook-name>/
# - LaunchAgent runs maestro-cli on schedule
# - Maestro spawns isolated Claude CLI sessions per document
# - State tracked via markdown checkboxes
#
# Usage:
#   programs.maestro = {
#     enable = true;
#     issueResolver = {
#       enable = true;
#       schedule = { hour = 9; minute = 0; };
#       targetRepository = "~/git/nix-config/main";
#     };
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.maestro;
  homeDir = config.home.homeDirectory;

  # Playbook files for issue-resolver
  issueResolverPlaybooks = {
    "Maestro/Auto Run Docs/issue-resolver/1_SURVEY_ISSUES.md" = {
      source = ./playbooks/issue-resolver/1_SURVEY_ISSUES.md;
    };
    "Maestro/Auto Run Docs/issue-resolver/2_EVALUATE_FIXABILITY.md" = {
      source = ./playbooks/issue-resolver/2_EVALUATE_FIXABILITY.md;
    };
    "Maestro/Auto Run Docs/issue-resolver/3_CREATE_PLAN.md" = {
      source = ./playbooks/issue-resolver/3_CREATE_PLAN.md;
    };
    "Maestro/Auto Run Docs/issue-resolver/4_EXECUTE_FIX.md" = {
      source = ./playbooks/issue-resolver/4_EXECUTE_FIX.md;
    };
    "Maestro/Auto Run Docs/issue-resolver/5_CHECK_PROGRESS.md" = {
      source = ./playbooks/issue-resolver/5_CHECK_PROGRESS.md;
    };
  };
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    # Deploy maestro-cli wrapper and playbooks
    home.file = lib.mkMerge [
      {
        ".local/bin/maestro-cli" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            # Maestro CLI Wrapper
            #
            # Invokes Maestro Electron app in CLI mode for automated playbook execution.
            # The Maestro app supports headless CLI commands for scheduled automation.
            #
            # Usage: maestro-cli <args...>  # passes all arguments to Maestro CLI

            set -euo pipefail

            # Path to Maestro Electron app
            MAESTRO_APP="${cfg.appPath}"

            # Verify Maestro is installed
            if [ ! -x "$MAESTRO_APP" ]; then
              echo "Error: Maestro not found at $MAESTRO_APP" >&2
              echo "Please install Maestro from: https://www.maestro.app" >&2
              exit 1
            fi

            # Pass all arguments to Maestro CLI
            exec "$MAESTRO_APP" "$@"
          '';
        };
      }
      (lib.mkIf cfg.issueResolver.enable issueResolverPlaybooks)
    ];

    # LaunchAgent for scheduled execution
    launchd.agents = lib.optionalAttrs cfg.issueResolver.enable {
      "com.maestro.issue-resolver" = {
        enable = true;
        config = {
          Label = "com.maestro.issue-resolver";
          ProgramArguments = [
            "${homeDir}/.local/bin/maestro-cli"
            "playbook"
            "run"
            "${homeDir}/Maestro/Auto Run Docs/issue-resolver"
            "--json"
          ];
          StartCalendarInterval = [
            {
              Hour = cfg.issueResolver.schedule.hour;
              Minute = cfg.issueResolver.schedule.minute;
            }
          ];
          StandardOutPath = "${homeDir}/.maestro/logs/issue-resolver-stdout.log";
          StandardErrorPath = "${homeDir}/.maestro/logs/issue-resolver-stderr.log";
          EnvironmentVariables = {
            HOME = homeDir;
            PATH = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
            GH_CONFIG_DIR = "${homeDir}/.config/gh";
            # Target repository for playbook
            MAESTRO_CURRENT_REPO = cfg.issueResolver.targetRepository;
          };
        };
      };
    };

    # Create log directory
    home.activation.createMaestroLogs = lib.mkIf cfg.issueResolver.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "${homeDir}/.maestro/logs"
      ''
    );
  };
}
