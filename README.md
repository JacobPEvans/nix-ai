# nix-ai

## Your AI coding toolkit, declared once. Reproduced everywhere

Ever spent hours configuring Claude Code plugins, Gemini settings, and MCP servers
-- only to lose it all when you switch machines?
**nix-ai** captures your entire AI setup as code using [Nix](https://nixos.org/).
One command rebuilds everything, identically, every time.

---

## What it manages

| Tool | What you get |
| ---- | ------------ |
| **Claude Code** | Plugins, marketplace, statusline, settings, autonomous agents, hooks |
| **Gemini CLI** | Settings, custom commands, permission rules |
| **GitHub Copilot** | Configuration, permissions |
| **OpenAI Codex** | Settings |
| **MCP Servers** | 15+ servers — GitHub, Terraform, Context7, PAL, filesystem, memory, and more |
| **Plugin Marketplace** | 14 curated plugin repositories |
| **AI Dev Tools** | cclint, doppler-mcp, claude-flow, sync-ollama-models |
| **Ollama** | Local model management with macOS launchd integration |

## Prerequisites

- [Nix](https://nixos.org/) (Determinate Nix recommended)
- [home-manager](https://github.com/nix-community/home-manager)
- Compatible platform: `aarch64-darwin` or `x86_64-linux`

## Quick start

Add to your Nix flake:

```nix
{
  inputs.nix-ai = {
    url = "github:JacobPEvans/nix-ai";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
}
```

Then in your home-manager config:

```nix
sharedModules = [ nix-ai.homeManagerModules.default ];
```

That's it. Every AI tool, every plugin, every permission rule — managed by Nix.

## How it works

nix-ai exports [home-manager](https://github.com/nix-community/home-manager) modules that merge into your existing configuration:

| Export | What it includes |
| ------ | --------------- |
| `homeManagerModules.default` | Full AI stack — Claude, Gemini, Copilot, Codex, MCP, Ollama, dev tools |
| `homeManagerModules.claude` | Just Claude Code |
| `homeManagerModules.maestro` | Just Maestro orchestration |
| `lib.ci.claudeSettingsJson` | Pure JSON for CI validation (no derivations needed) |

### Self-contained design

The module injects its own dependencies via `_module.args`. Your consuming flake only needs two lines:

```nix
inputs.nixpkgs.follows = "nixpkgs";
inputs.home-manager.follows = "home-manager";
```

No AI-specific inputs to wire up. No extra configuration. It just works.

## Available module options

Key enable toggles exposed by the default module:

| Option | Type | Default | Description |
| ------ | ---- | ------- | ----------- |
| `programs.claude.enable` | bool | — | Enable Claude Code configuration |
| `programs.claude.apiKeyHelper.enable` | bool | false | Headless API key authentication via Bitwarden |
| `programs.claudeStatusline.enable` | bool | true | Claude Code powerline statusline |
| `programs.claude.settings.sandbox.enabled` | bool | false | Filesystem/network sandbox isolation |
| `programs.claude.settings.alwaysThinkingEnabled` | bool | true | Extended thinking mode |
| `programs.claude.remoteControlAtStartup` | bool or null | null | Remote Control auto-start |
| `programs.claude.model` | string or null | null | Override default model (e.g. `"opus"`, `"sonnet"`) |
| `programs.claude.effortLevel` | enum or null | `null` | Adaptive reasoning effort (`"low"`, `"medium"`, `"high"`); `null` uses the upstream default. |
| `programs.claude.trustedProjectDirs` | list of str | `[]` | Base directories for auto-trust of CLAUDE.md imports |

For the full option set, see [`modules/claude/options.nix`](modules/claude/options.nix).

## Testing and validation

Run quality checks locally:

```bash
nix flake check
```

This runs formatting (nixfmt), static analysis (statix), dead code detection (deadnix),
shell script linting (shellcheck), and full module evaluation (module-eval) to verify
the home-manager module instantiates correctly with real inputs.

Fix formatting automatically:

```bash
nix fmt
```

## Repository structure

```text
modules/
├── claude/          # Claude Code (settings, plugins, statusline, auto-claude)
├── maestro/         # Maestro agent orchestration
├── mcp/             # 15+ MCP server definitions
├── common/          # Shared permission engine
├── gh-extensions/   # GitHub CLI extensions (gh-aw)
├── permissions/     # Per-tool permission rules
├── ollama.nix       # Local model management
├── ai-tools.nix     # AI development tool packages
├── gemini.nix       # Gemini CLI configuration
├── copilot.nix      # GitHub Copilot configuration
└── codex.nix        # OpenAI Codex configuration
lib/
├── claude-settings.nix    # Pure settings generator
├── claude-registry.nix    # Marketplace format functions
└── security-policies.nix  # Permission policy engine
```

## Part of a trio

This repo is one of three that work together:

| Repo | What it does |
| ---- | ------------ |
| **nix-ai** (you are here) | AI coding tools |
| [nix-home](https://github.com/JacobPEvans/nix-home) | Dev environment (git, zsh, VS Code, tmux) |
| [nix-darwin](https://github.com/JacobPEvans/nix-darwin) | macOS system config (consumes both) |

## License

MIT
