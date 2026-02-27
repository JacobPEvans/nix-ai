# Claude Code Plugin Management
#
# Symlinks Nix-managed plugin directories from flake inputs.
# Runtime plugins are unaffected - they live in separate directories.
#
# Uses `recursive = true` to create per-file symlinks inside each marketplace
# directory, rather than symlinking the entire directory. This allows Claude
# Code's extra files (.git/, caches) to coexist without conflict, and avoids
# "cannot overwrite directory with symlink" errors on darwin-rebuild switch.
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
      recursive = true;
      force = true;
    }
  ) nixManagedMarketplaces;

in
{
  config = lib.mkIf cfg.enable {
    home.file = marketplaceSymlinks;
  };
}
