# Claude Code Plugin Management
#
# Symlinks Nix-managed plugin directories from flake inputs as single directory
# symlinks (home-manager's default: recursive = false). Claude Code only READS
# from ~/.claude/plugins/marketplaces/ — it writes exclusively to
# ~/.claude/plugins/cache/. Since marketplaces are read-only, immutable nix
# store symlinks are the correct approach.
#
# IMPORTANT: Do NOT add `recursive = true` or `force = true`:
# - recursive = true creates per-file symlinks, allowing .backup pollution
# - force = true causes home-manager to rename existing files to .backup,
#   which pollute Claude Code's plugin cache when it re-indexes
# Phase 1 of orphan-cleanup.nix handles the one-time migration from
# recursive (real dirs) to directory symlinks.
{ config, lib, ... }:

let
  cfg = config.programs.claude;

  # Extract marketplace name from the identifier
  # e.g., "anthropics/claude-plugins-official" -> "claude-plugins-official"
  # Implementation matches lib/claude-registry.nix for consistency
  getMarketplaceName = name: lib.last (lib.splitString "/" name);

  # Create symlink entries for Nix-managed marketplaces
  nixManagedMarketplaces = lib.filterAttrs (_: m: m.flakeInput != null) cfg.plugins.marketplaces;

  marketplaceSymlinks = lib.mapAttrs' (
    name: marketplace:
    lib.nameValuePair ".claude/plugins/marketplaces/${getMarketplaceName name}" {
      source = marketplace.flakeInput;
    }
  ) nixManagedMarketplaces;

in
{
  config = lib.mkIf cfg.enable {
    home.file = marketplaceSymlinks;
  };
}
