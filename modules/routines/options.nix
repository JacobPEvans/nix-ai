# Routines Options
#
# Generic scheduled task options for running AI CLI commands via launchd.
# Each task has a prompt, AI tool selection, schedule, and working directory.
# Implementation in ./default.nix
{ lib, ... }:

{
  options.programs.routines = {
    enable = lib.mkEnableOption "Scheduled AI routines via launchd";

    logDir = lib.mkOption {
      type = lib.types.str;
      default = ".routines/logs";
      description = "Log directory relative to home directory";
    };

    promptsDir = lib.mkOption {
      type = lib.types.str;
      default = ".routines/prompts";
      description = "Prompt files directory relative to home directory";
    };

    scriptsDir = lib.mkOption {
      type = lib.types.str;
      default = ".routines/scripts";
      description = "Runner scripts directory relative to home directory";
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            prompt = lib.mkOption {
              type = lib.types.str;
              description = "Prompt text to pass to the AI CLI";
            };

            aiTool = lib.mkOption {
              type = lib.types.enum [
                "gemini"
                "claude"
              ];
              default = "gemini";
              description = "AI CLI to use for this task";
            };

            model = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Model override passed to the AI CLI.
                null = use the tool's configured default.
                Examples: "gemini-2.5-pro", "claude-sonnet-4-6"
              '';
            };

            schedule = lib.mkOption {
              type = lib.types.submodule {
                options = {
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
                      List of times to run each day.
                      Example:
                        times = [{ hour = 6; minute = 13; }];
                    '';
                  };

                  hour = lib.mkOption {
                    type = lib.types.nullOr (lib.types.ints.between 0 23);
                    default = null;
                    description = "Single hour shorthand (deprecated in favor of times)";
                  };
                };
              };
              description = "When to run the task";
            };

            workingDirectory = lib.mkOption {
              type = lib.types.str;
              description = "Working directory for the launchd agent (absolute path)";
            };

            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether this task's schedule is active";
            };
          };
        }
      );
      default = { };
      description = "Scheduled AI routine tasks";
    };
  };
}
