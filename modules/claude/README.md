# Claude Code Module

Home-manager module for Claude Code configuration. Manages plugins, hooks, agents, commands,
rules, settings, and statusline via `programs.claude.*` options.

Configured in [`modules/claude-config.nix`](../claude-config.nix). Deployed to `~/.claude/` by home-manager.

## Component Map

| Component | Location | Description |
| --------- | -------- | ----------- |
| Plugins | [`plugins/`](plugins/) | Marketplaces and enabled plugins — [full catalog](plugins/README.md) |
| Hooks | [`hooks/`](hooks/) | Event-driven shell scripts triggered by Claude Code |
| Agents | flake input: `claude-cookbooks` | Subagent persona definitions deployed to `~/.claude/agents/` |
| Commands | flake input: `claude-cookbooks` | Slash commands deployed to `~/.claude/commands/` |
| Rules | flake input: `ai-assistant-instructions` + [`rules/`](rules/) | Global instructions loaded every session |
| Settings | [`settings.nix`](settings.nix), [`options.nix`](options.nix) | Generates `~/.claude/settings.json` |
| Statusline | [`statusline/`](statusline/) | Powerline integration for terminal status display |

## Hooks

Defined in [`claude-config.nix`](../claude-config.nix), scripts in [`hooks/`](hooks/).

| Event | Script | Trigger | What It Does |
| ----- | ------ | ------- | ------------ |
| `preToolUse` | [`ask-user-notify.sh`](hooks/ask-user-notify.sh) | `AskUserQuestion` tool call | Sends Slack notification for async/mobile workflow |
| `postToolUse` | [`last-output.sh`](hooks/last-output.sh) | Every tool execution | Writes compact summary to `~/.cache/claude-last-output.txt` |

The Slack hook requires `SLACK_CHANNEL` env var or a matching keychain entry
(`SLACK_CHANNEL_<REPO>`). Exits silently if not configured.

Available hook events: `preToolUse`, `postToolUse`, `userPromptSubmit`, `stop`,
`subagentStop`, `sessionStart`, `sessionEnd`.

## Agents

Deployed to `~/.claude/agents/` from flake inputs via [`components.nix`](components.nix).

| Agent | Source | Description |
| ----- | ------ | ----------- |
| `code-reviewer` | `claude-cookbooks` | Code review for Cookbook repo notebooks |

Plugin-provided agents (from marketplace plugins) are separate — see the
[plugin catalog](plugins/README.md) for plugins that include agents.

## Commands

Deployed to `~/.claude/commands/` from flake inputs via [`components.nix`](components.nix).

| Command | Source | Description |
| ------- | ------ | ----------- |
| `/add-registry` | `claude-cookbooks` | Add a notebook to registry.yaml |
| `/link-review` | `claude-cookbooks` | Review links in changed files |
| `/model-check` | `claude-cookbooks` | Validate Claude model usage against current public models |
| `/notebook-review` | `claude-cookbooks` | Comprehensive Jupyter notebook review |
| `/review-issue` | `claude-cookbooks` | Review and respond to a GitHub issue |
| `/review-pr` | `claude-cookbooks` | Review an open pull request |
| `/review-pr-ci` | `claude-cookbooks` | Review a pull request (CI/automated use) |

Plugin-provided commands (from marketplace plugins) are separate — see the
[plugin catalog](plugins/README.md) for plugins that include slash commands.

## Rules

Global rules load every session. Deployed to `~/.claude/rules/` via [`components.nix`](components.nix).

### From `ai-assistant-instructions/agentsmd/rules/`

| Rule | Scope |
| ---- | ----- |
| `ci-cd-policy` | CI/CD automation guidance |
| `config-secrets` | Secret scrubbing details for config files |
| `nix-package-placement` | Nix package placement decision matrix (path-scoped: `*.nix`) |
| `nix-tool-policy` | Nix dev shell tool usage rules (path-scoped: `*.nix`) |
| `secrets-policy` | Never commit secrets (universal) |
| `skill-execution-integrity` | Every skill invocation is fresh, not a continuation |
| `soul` | AI personality and voice guidelines |
| `tool-use` | Native tools over Bash, subagent dispatching, script policy |
| `infra/pre-integration-checklist` | Infrastructure pre-integration validation |

### Local rules — [`rules/`](rules/)

| Rule | When Applied |
| ---- | ------------ |
| `pal-mcp-policy` | Always; PAL MCP availability protocol, clink/consensus escalation |
| `retrospective-report-location` | Routes retrospective reports to `~/.claude/skills/retrospecting/reports/` |

## Plugins

See the [Plugin Catalog](plugins/README.md) for the full list of marketplaces
and enabled plugins organized by category.

## Key Nix Files

| File | Role |
| ---- | ---- |
| [`claude-config.nix`](../claude-config.nix) | Top-level values: model, effort, hooks, agents, commands, rules |
| [`plugins/default.nix`](plugins/default.nix) | Merges all plugin category files |
| [`plugins/marketplaces.nix`](plugins/marketplaces.nix) | Marketplace definitions |
| [`settings.nix`](settings.nix) | Generates `settings.json`, wires hooks to `~/.claude/hooks/` |
| [`components.nix`](components.nix) | Deploys agents, commands, skills, rules as symlinks |
| [`options.nix`](options.nix) | All `programs.claude.*` option declarations |
| [`marketplace-overrides.nix`](marketplace-overrides.nix) | Synthetic marketplace derivations |
| [`orphan-cleanup.nix`](orphan-cleanup.nix) | Runtime cache cleanup on `darwin-rebuild switch` |

## Related Docs

- [MCP Servers](../mcp/README.md) — 15+ MCP server definitions
- [Fabric Module](../fabric/README.md) — Fabric CLI and pattern integration
- [Auto-Claude Testing](TESTING.md) — Autonomous agent testing procedures
- [Plugin Cache Architecture](../../.claude/rules/plugin-cache-architecture.md) — Marketplace symlink and cache rules
