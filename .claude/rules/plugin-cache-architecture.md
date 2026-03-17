# Plugin Cache Architecture

## Marketplace Symlinks

Marketplace directories (`~/.claude/plugins/marketplaces/`) are single directory symlinks
to the Nix store, NOT recursive per-file symlinks.

**Never use `recursive = true` or `force = true` in `plugins.nix`:**

- `recursive = true` creates per-file symlinks, which allows `.backup` file pollution
- `force = true` causes home-manager to rename existing files to `.backup`, polluting
  Claude Code's plugin cache when it re-indexes from marketplaces
- Neither is needed because Claude Code only READS from marketplaces

## Read/Write Separation

- **Marketplaces** (`~/.claude/plugins/marketplaces/`): Read-only. Managed by Nix.
  Claude Code reads plugin definitions from here but never writes.
- **Cache** (`~/.claude/plugins/cache/`): Read-write. Owned by Claude Code.
  Plugin state, indexes, and cached data live here.

## Never Delete Plugin Cache Mid-Session

Deleting `~/.claude/plugins/cache/` or `~/.claude/plugins/installed_plugins.json` during
an active Claude Code session creates an unbreakable hook error loop. All registered hooks
(PreToolUse, PostToolUse, Stop) reference files inside the cache directory. Deleting it
causes every hook invocation to fail, including the Stop hook, creating an infinite error
loop that requires force-killing the process.

Cache staleness is handled automatically by `verify-cache-integrity.sh` on every
`darwin-rebuild switch`. No manual cache deletion is ever needed.

## Migration Path

Phase 1 of `orphan-cleanup.nix` handles the one-time migration from `recursive = true`
(real directories with per-file symlinks) to directory symlinks. After the first rebuild,
marketplace paths are already symlinks and the migration code is a no-op.
