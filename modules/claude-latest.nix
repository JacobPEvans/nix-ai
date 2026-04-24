{
  config,
  lib,
  pkgs,
  ...
}:
#
# claude-latest install module
#
# Manages the bleeding-edge Claude Code native install at ~/.local/bin/claude,
# coexisting with Homebrew's /opt/homebrew/bin/claude (stable). Aliases that
# disambiguate `claude` vs `claude-latest` live in modules/ai-aliases.zsh.
#
# Pattern: mirrors nix-darwin/modules/darwin/apps/cribl-edge.nix — committed
# shell file wrapped via pkgs.writeShellApplication, invoked declaratively by
# a LaunchAgent. No home.activation for software installs.
#
# After first install, Claude Code's own `claude update` command keeps the
# binary current — this module only bootstraps a missing install and provides
# an on-demand `claude-latest-install` command.
#
# Web docs: https://claude.ai/install.sh
#
let
  cfg = config.programs.claude-latest;

  installScript = pkgs.writeShellApplication {
    name = "claude-latest-install";
    runtimeInputs = [
      pkgs.curl
      pkgs.bash
      pkgs.coreutils
    ];
    text = builtins.readFile ./claude/scripts/claude-latest-install.sh;
  };
in
{
  options.programs.claude-latest = {
    enable = lib.mkEnableOption "bleeding-edge Claude Code install at ~/.local/bin/claude via the official installer";
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    # On PATH for manual re-install or forced re-run.
    home.packages = [ installScript ];

    # Fires once at login; no-op when already installed (script is idempotent).
    # KeepAlive = false: we only care about bootstrap, not a long-running service.
    launchd.agents.claude-latest-install = {
      enable = true;
      config = {
        Label = "com.jacobpevans.claude-latest-install";
        ProgramArguments = [ "${installScript}/bin/claude-latest-install" ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/ClaudeLatest/install.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/ClaudeLatest/install.error.log";
      };
    };

    # Ensure the logs directory exists so launchd doesn't bail on first run.
    home.file."Library/Logs/ClaudeLatest/.keep".text = "";
  };
}
