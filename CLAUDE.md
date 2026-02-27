# nix-ai - AI Agent Instructions

AI CLI ecosystem for Claude, Gemini, Copilot, MCP servers via Nix home-manager modules.

## Critical Constraints

1. **Flakes-only**: Never use `nix-env` or imperative Nix commands
2. **Module args injection**: All flake inputs reach modules via `_module.args`, not function parameters
3. **Worktrees required**: Run `/init-worktree` before any work
4. **No direct main commits**: Always use feature branches

## Build Validation

```bash
nix flake check    # Runs formatting, statix, deadnix checks
nix fmt            # Fix formatting
```

## Architecture

This repo exports home-manager modules consumed by nix-config (nix-darwin):

- `homeManagerModules.default` — Full AI stack
- `homeManagerModules.claude` — Claude Code only
- `homeManagerModules.maestro` — Maestro orchestration only
- `lib.ci.claudeSettingsJson` — Pure JSON for CI validation

### Self-contained design

Modules inject their own dependencies via `_module.args`. Consumers only need:

```nix
inputs.nix-ai.inputs.nixpkgs.follows = "nixpkgs";
inputs.nix-ai.inputs.home-manager.follows = "home-manager";
```

## Key Files

- `modules/default.nix` — Module entry point (imports all AI modules)
- `modules/claude/` — Claude Code settings, plugins, statusline, auto-claude
- `modules/mcp/` — MCP server definitions
- `modules/common/` — Shared permission engine and formatters
- `lib/claude-settings.nix` — Pure settings generator
- `lib/claude-registry.nix` — Marketplace format functions

## Testing Locally

From nix-config (nix-darwin), test changes with:

```bash
sudo darwin-rebuild switch --flake . --override-input nix-ai /Users/you/git/nix-ai/main
```

## Part of a Trio

| Repo | Purpose |
| ---- | ------- |
| **nix-ai** (this repo) | AI coding tools |
| [nix-home](https://github.com/JacobPEvans/nix-home) | Dev environment (git, zsh, VS Code, tmux) |
| [nix-config](https://github.com/JacobPEvans/nix) | macOS system config (consumes both) |
