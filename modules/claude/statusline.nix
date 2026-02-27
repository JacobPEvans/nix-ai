# Claude Code Statusline Module (Legacy)
#
# Builds and configures claude-code-statusline from flake input.
# Creates wrapper package and manages config files.
# Supports SSH detection for mobile-friendly single-line display.
# Uses bun for ccusage cost tracking integration.
#
# NOTE: This is the legacy module. For theme-based statusline, use
# programs.claudeStatusline with the statusline/options.nix module.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;

  # Import shared package builder
  inherit (import ./statusline/package.nix { inherit lib pkgs; }) mkStatuslinePackage;

in
{
  config = lib.mkIf (cfg.enable && cfg.statusLine.enable && cfg.statusLine.enhanced.enable) (
    let
      statuslinePackage = mkStatuslinePackage cfg.statusLine.enhanced.source;

      # Config files - full (local) and mobile (SSH)
      configFull =
        if cfg.statusLine.enhanced.configFile != null then
          cfg.statusLine.enhanced.configFile
        else
          "${cfg.statusLine.enhanced.source}/examples/Config.toml";

      configMobile = cfg.statusLine.enhanced.mobileConfigFile;
    in
    {
      # Export the package for settings.nix to reference
      programs.claude.statusLine.enhanced.package = statuslinePackage;

      # Install the statusline package
      home.packages = [ statuslinePackage ];

      # Deploy config files
      home.file = {
        # Full config (always deployed)
        ".claude/statusline/config-full.toml".source = configFull;
      }
      // lib.optionalAttrs (configMobile != null) {
        # Mobile config (only if specified)
        ".claude/statusline/config-mobile.toml".source = configMobile;
      };
    }
  );
}
