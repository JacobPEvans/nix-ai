# Routines: Scheduled AI Routine Tasks via launchd
#
# Creates macOS launchd agents that run AI CLI tools (Gemini, Claude) on a
# schedule with a configured prompt. Each task:
#   - Deploys its prompt to ~/.routines/prompts/<name>.txt
#   - Deploys a runner script to ~/.routines/scripts/<name>.sh
#   - Creates a launchd agent: com.routines.<name>
#   - Logs stdout to ~/.routines/logs/<name>.log
#   - Logs stderr to ~/.routines/logs/<name>.err
#
# Options defined in: ./options.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.routines;
  homeDir = config.home.homeDirectory;
  logDir = "${homeDir}/${cfg.logDir}";
  promptsDir = "${homeDir}/${cfg.promptsDir}";
  scriptsDir = "${homeDir}/${cfg.scriptsDir}";

  # Convert {hour, minute} attrset to launchd StartCalendarInterval entry
  mkCalendarInterval =
    time:
    {
      Hour = time.hour;
      Minute = time.minute;
    };

  # Resolve schedule to a list of {hour, minute} attrsets
  getScheduleTimes =
    schedule:
    if schedule.times != [ ] then
      schedule.times
    else if schedule.hour != null then
      [ { hour = schedule.hour; minute = 0; } ]
    else
      [ ];

  # Only process enabled tasks
  enabledTasks = lib.filterAttrs (_: task: task.enabled) cfg.tasks;

  # Build the run command for a task based on its AI tool
  mkRunCommand =
    name: task:
    let
      promptFile = "${promptsDir}/${name}.txt";
      modelFlag = lib.optionalString (task.model != null) "--model '${task.model}'";
    in
    if task.aiTool == "gemini" then
      "gemini -p \"$(cat '${promptFile}')\" ${modelFlag}"
    else
      # Claude: use --print flag for non-interactive output
      "claude --print ${modelFlag} < '${promptFile}'";

  # Generate a runner script for a task
  mkRunnerScript =
    name: task:
    let
      logFile = "${logDir}/${name}.log";
      errFile = "${logDir}/${name}.err";
      runCmd = mkRunCommand name task;
    in
    pkgs.writeShellScript "routine-${name}" ''
      #!/usr/bin/env zsh
      set -euo pipefail

      mkdir -p '${logDir}'

      log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] ${name}: $2" >> '${logFile}'
      }

      log "START" "routine triggered"

      ${runCmd} >> '${logFile}' 2>> '${errFile}'
      EXIT_CODE=$?

      if [[ $EXIT_CODE -eq 0 ]]; then
        log "END" "completed successfully"
      else
        log "END" "failed with exit code $EXIT_CODE"
      fi

      exit $EXIT_CODE
    '';

in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList (
      name: task:
      let
        timesList = getScheduleTimes task.schedule;
      in
      {
        assertion = (!task.enabled) || (timesList != [ ]);
        message = "programs.routines.tasks.${name} must set schedule.times when enabled";
      }
    ) enabledTasks;

    home.file =
      # Deploy prompt files
      (lib.mapAttrs' (
        name: task:
        lib.nameValuePair "${cfg.promptsDir}/${name}.txt" {
          text = task.prompt;
        }
      ) enabledTasks);

    # Create launchd agents for each enabled task
    launchd.agents = lib.mapAttrs' (
      name: task:
      let
        timesList = getScheduleTimes task.schedule;
        runnerScript = mkRunnerScript name task;
        logFile = "${logDir}/${name}.log";
        errFile = "${logDir}/${name}.err";
      in
      lib.nameValuePair "com.routines.${name}" {
        enable = task.enabled;
        config = {
          Label = "com.routines.${name}";
          # Inherit Full Disk Access from Ghostty via TCC association
          AssociatedBundleIdentifiers = [ "com.mitchellh.ghostty" ];
          ProgramArguments = [ "${runnerScript}" ];
          StartCalendarInterval = map mkCalendarInterval timesList;
          StandardOutPath = logFile;
          StandardErrorPath = errFile;
          WorkingDirectory = task.workingDirectory;
          EnvironmentVariables = {
            HOME = homeDir;
            # gh CLI auth via config directory (token in ~/.config/gh/hosts.yml)
            GH_CONFIG_DIR = "${homeDir}/.config/gh";
            # SSH batch mode for git operations (no interactive prompts)
            GIT_SSH_COMMAND = "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes";
            # Full PATH: per-user Nix profile + system paths
            PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      }
    ) enabledTasks;
  };
}
