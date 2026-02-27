# Auto-Claude Menu Bar Status
#
# SwiftBar plugin for monitoring auto-claude status in real-time.
# Shows current state (active/paused/running) and provides quick actions.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;

  # SwiftBar plugin script - reference external Python file
  menubarScript = ./auto-claude-status.py;

  # Use a simple path without spaces for reliability
  pluginDir = ".config/swiftbar/plugins";
  pluginName = "auto-claude.${toString cfg.menubar.refreshInterval}s.py";

in
{
  options.programs.claude.menubar = {
    enable = lib.mkEnableOption "Auto-Claude menu bar status via SwiftBar";

    refreshInterval = lib.mkOption {
      type = lib.types.ints.between 1 86400;
      default = 30;
      description = "Refresh interval in seconds for the menu bar plugin (1 second to 24 hours)";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.menubar.enable) {
    # Deploy the SwiftBar plugin
    home.file."${pluginDir}/${pluginName}" = {
      source = menubarScript;
      executable = true;
    };

    # Note: User must configure SwiftBar to use ~/.config/swiftbar/plugins/
    # on first launch, or symlink from their chosen location.

    # Add a note about SwiftBar setup
    warnings = lib.optional (!config.programs.claude.autoClaude.enable) ''
      programs.claude.menubar is enabled but programs.claude.autoClaude is not.
      The menu bar will show status but auto-claude won't be running.
    '';
  };
}
