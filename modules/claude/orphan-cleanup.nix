# Orphan Cleanup Module
#
# Three-phase cleanup for Nix-managed directories:
#
# Phase 1 (BEFORE linkGeneration):
# - Removes directory symlinks pointing to the nix store that conflict with
#   individual file symlinks in the new generation.
# - Also removes stale root-level symlinks whose nix store targets no longer exist.
#
# Phase 2 (AFTER linkGeneration):
# - Removes broken symlinks (targets that no longer exist) inside component dirs.
#
# Phase 3 (AFTER linkGeneration):
# - Verifies plugin cache integrity when marketplace symlinks change.
#
{ config, lib, ... }:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;

  componentDirs = [
    "${homeDir}/.claude/commands"
    "${homeDir}/.claude/agents"
    "${homeDir}/.claude/skills"
    "${homeDir}/.gemini/commands"
  ];

  getMarketplaceName = name: lib.last (lib.splitString "/" name);
  nixManagedMarketplaces = lib.filterAttrs (_: m: m.flakeInput != null) cfg.plugins.marketplaces;
  marketplaceDirs = lib.mapAttrsToList (
    name: _: "${homeDir}/.claude/plugins/marketplaces/${getMarketplaceName name}"
  ) nixManagedMarketplaces;

in
{
  config = lib.mkIf cfg.enable {
    home.activation = {
      # Phase 1: Remove conflicting directory symlinks BEFORE linkGeneration.
      cleanupConflictingDirectorySymlinks = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        . ${./scripts/cleanup-conflicting-symlinks.sh} \
          ${lib.escapeShellArgs (componentDirs ++ marketplaceDirs)}
        . ${./scripts/cleanup-stale-symlinks.sh} \
          "${homeDir}/CLAUDE.md" "${homeDir}/GEMINI.md" "${homeDir}/AGENTS.md" "${homeDir}/agentsmd"
      '';

      # Phase 2: Remove orphan symlinks AFTER linkGeneration creates new ones.
      cleanupOrphanComponents = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        . ${./scripts/cleanup-broken-symlinks.sh} \
          ${lib.escapeShellArgs (
            [
              "command"
              "${homeDir}/.claude/commands"
              "agent"
              "${homeDir}/.claude/agents"
              "skill"
              "${homeDir}/.claude/skills"
              "gemini command"
              "${homeDir}/.gemini/commands"
            ]
            ++ (lib.concatMap (dir: [
              "marketplace file"
              dir
            ]) marketplaceDirs)
          )}
      '';

      # Phase 3: Verify plugin cache integrity AFTER linkGeneration.
      # See: https://github.com/anthropics/claude-code/issues/17361
      verifyCacheIntegrity = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD ${./scripts/verify-cache-integrity.sh} "${homeDir}"
      '';
    };
  };
}
