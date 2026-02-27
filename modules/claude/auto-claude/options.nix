# Auto-Claude Options
#
# Options for scheduled autonomous maintenance via launchd agents.
# Implementation in ../auto-claude.nix
{ lib, ... }:

{
  options.programs.claude.autoClaude = {
    enable = lib.mkEnableOption "Auto-Claude scheduled maintenance";

    repositories = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path to the git repository";
            };

            schedule = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  hour = lib.mkOption {
                    type = lib.types.nullOr (lib.types.ints.between 0 23);
                    default = null;
                    description = "Hour of day to run (0-23). Deprecated in favor of hours/times.";
                  };

                  hours = lib.mkOption {
                    type = lib.types.listOf (lib.types.ints.between 0 23);
                    default = [ ];
                    description = ''
                      List of hours (0-23) to run each day at minute 0.
                      Deprecated in favor of times for hour+minute control.

                      If empty and schedule.hour is set, falls back to that single hour.
                      Example: To run every 2 hours, set to [0 2 4 6 8 10 12 14 16 18 20 22].
                    '';
                  };

                  times = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          hour = lib.mkOption {
                            type = lib.types.ints.between 0 23;
                            description = "Hour of day (0-23)";
                          };
                          minute = lib.mkOption {
                            type = lib.types.ints.between 0 59;
                            default = 0;
                            description = "Minute of hour (0-59)";
                          };
                        };
                      }
                    );
                    default = [ ];
                    description = ''
                      List of times to run each day. Each time has hour (0-23) and minute (0-59).

                      If empty, falls back to the deprecated 'hours' or 'hour' options.
                      Default runs once daily at 2:00 PM to minimize unexpected costs.
                      Add more times for more frequent maintenance runs.

                      Example:
                        times = [
                          { hour = 9; minute = 30; }   # 9:30 AM
                          { hour = 14; minute = 0; }   # 2:00 PM
                          { hour = 18; minute = 30; }  # 6:30 PM
                        ];
                    '';
                  };
                };
              };
              description = "When to run the maintenance task";
            };

            maxBudget = lib.mkOption {
              type = lib.types.float;
              default = 50.0;
              description = ''
                Maximum cost per run in USD. Uses Haiku model exclusively.

                IMPORTANT: This default is set to $50.0 and uses Claude Haiku exclusively.
                Auto-claude enforces Haiku-only operation via environment variables,
                settings.json, and explicit --model haiku flag for defense-in-depth.

                With the default once-daily schedule, this means up to $50/day per repository.
                Haiku provides cost-effective operation while maintaining quality output.
              '';
            };

            model = lib.mkOption {
              type = lib.types.str;
              default = "haiku";
              description = ''
                Claude model to use for auto-claude runs.

                Strongly recommended: "haiku" - cost-effective, excellent for autonomous tasks
                Alternatives: "sonnet", "opus" (significantly higher cost)
              '';
            };

            slackChannel = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Slack channel ID for notifications (e.g., C0123456789)";
            };

            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this repository's schedule is active";
            };
          };
        }
      );
      default = { };
      description = "Repositories to run auto-claude on";
    };
  };
}
