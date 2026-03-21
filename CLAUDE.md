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

This repo exports home-manager modules consumed by nix-darwin:

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
- `modules/mlx/` — MLX inference server (vllm-mlx LaunchAgent, CLI tools, perf tuning)
- `modules/common/` — Shared permission engine and formatters
- `lib/claude-settings.nix` — Pure settings generator (CI-only; deployment uses modules/claude/settings.nix)
- `lib/claude-registry.nix` — Marketplace format functions
- `lib/checks.nix` — Check aggregator (imports lib/checks/{lint,claude,mlx}.nix)
- `lib/checks/lint.nix` — Formatting, statix, deadnix, shellcheck
- `lib/checks/claude.nix` — Claude module regression tests, settings-json, maestro-script
- `lib/checks/mlx.nix` — MLX option/defaults regression, LaunchAgent flag validation

## Port Allocation

Services managed by nix-ai and their assigned ports. Check this table before assigning
new ports to avoid collisions (e.g., the 11434/11435/11436 fragmentation during the MLX arc).

| Port | Service | Protocol | Module |
| ---- | ------- | -------- | ------ |
| 11434 | vllm-mlx inference server | HTTP (OpenAI-compatible) | `modules/mlx/` |
| 8080 | Open WebUI | HTTP | `modules/open-webui.nix` |
| 27124 | Obsidian Local REST API | HTTP | `modules/mcp/` (env only) |

**Reserved/conflicting ports to avoid:**
- 11435: screenpipe (macOS app, not nix-ai managed — caused port collision in PR #230)

## Testing Locally

From nix-darwin, test changes with:

```bash
sudo darwin-rebuild switch --flake . --override-input nix-ai /Users/you/git/nix-ai/main
```

## Part of a Quartet

| Repo | Purpose |
| ---- | ------- |
| **nix-ai** (this repo) | AI coding tools |
| [nix-devenv](https://github.com/JacobPEvans/nix-devenv) | Reusable dev shells (Terraform, Ansible, K8s, AI/ML) |
| [nix-home](https://github.com/JacobPEvans/nix-home) | Dev environment (git, zsh, VS Code, tmux) |
| [nix-darwin](https://github.com/JacobPEvans/nix-darwin) | macOS system config (consumes all three) |
