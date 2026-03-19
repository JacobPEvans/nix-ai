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

    # After linkGeneration updates the marketplace symlinks to the new nix store
    # path, sync Claude Code's runtime plugin cache so it picks up new versions.
    # Only targets jacobpevans-cc-plugins — other marketplaces manage their own
    # update cadence. Fails open: if claude CLI is missing or updates fail, log
    # a warning and continue.
    home.activation.updateClaudePlugins =
      lib.hm.dag.entryAfter [ "linkGeneration" "verifyCacheIntegrity" ]
        ''
          # Resolve claude binary — activation runs as root via sudo so
          # homebrew/nix-profile paths aren't in PATH by default.
          CLAUDE=""
          for p in \
            "$(command -v claude 2>/dev/null)" \
            /opt/homebrew/bin/claude \
            /usr/local/bin/claude \
            "$HOME/.nix-profile/bin/claude" \
            /etc/profiles/per-user/*/bin/claude; do
            [ -n "$p" ] && [ -f "$p" ] && [ -x "$p" ] && CLAUDE="$p" && break
          done

          if [ -n "$DRY_RUN_CMD" ]; then
            echo "claude-plugins: dry-run — skipping plugin cache sync" >&2
          elif [ -n "$CLAUDE" ]; then
            echo "claude-plugins: syncing jacobpevans-cc-plugins cache (using $CLAUDE)..." >&2
            "$CLAUDE" plugins marketplace update jacobpevans-cc-plugins \
              || echo "claude-plugins: marketplace update failed (non-fatal)" >&2
            "$CLAUDE" plugins list | grep '@jacobpevans-cc-plugins' | sed 's/.*❯ //' \
              | while IFS= read -r plugin; do
                  "$CLAUDE" plugins update "$plugin" \
                    || echo "claude-plugins: failed to update $plugin (non-fatal)" >&2
                done
          else
            echo "claude-plugins: claude CLI not found — skipping plugin cache sync" >&2
          fi
        '';
  };
}
