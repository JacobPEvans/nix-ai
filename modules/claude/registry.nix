# Claude Code Plugin Registry
#
# Marketplace discovery is handled via extraKnownMarketplaces in settings.json.
# known_marketplaces.json is NOT Nix-managed - Claude Code owns it at runtime
# to support auto-update and dynamic marketplace management via the TUI.
#
# Previously, this module generated known_marketplaces.json as a Nix store
# symlink (read-only), which prevented Claude Code's "Enable auto-update"
# feature from working (EACCES permission denied).
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;
in
{
  config = lib.mkIf cfg.enable {
    # NOTE: known_marketplaces.json is NOT managed by Nix
    # Claude Code creates and manages this file at runtime.
    # Marketplace sources are declared via extraKnownMarketplaces in settings.json,
    # which Claude Code uses to populate known_marketplaces.json on first run.

    # NOTE: installed_plugins.json is NOT managed by Nix
    # Claude Code auto-creates this file on first plugin installation.
    # It's runtime state that Claude updates when plugins are installed/enabled.

    # Migration: Remove stale Nix symlink if it exists
    # After switching from Nix-managed to Claude-managed known_marketplaces.json,
    # the old symlink to /nix/store/... must be removed so Claude Code can create
    # a writable file in its place.
    home.activation.cleanupMarketplacesSymlink = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      MARKETPLACES="${homeDir}/.claude/plugins/known_marketplaces.json"
      . ${./scripts/cleanup-marketplaces-symlink.sh}
    '';
  };
}
