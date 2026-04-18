# Claude Code Plugin Catalog

Complete reference for all plugin marketplaces and enabled plugins managed by this module.

Parent doc: [`modules/claude/README.md`](../README.md)

## How Plugins Work

Plugins are referenced as `"plugin-name@marketplace-name"` pairs. Each marketplace is a GitHub repo
containing a `.claude-plugin/marketplace.json` manifest. Nix pins every marketplace as a flake input
for reproducible deployments. Setting a plugin to `true` enables it; `false` keeps it visible but disabled.

## Marketplaces

Registered marketplaces, defined in [`marketplaces.nix`](marketplaces.nix).

| Key | GitHub | Category |
| --- | ------ | -------- |
| `jacobpevans-cc-plugins` | `JacobPEvans/claude-code-plugins` | Personal |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Official Anthropic |
| `anthropic-agent-skills` | `anthropics/skills` | Official Anthropic |
| `cc-marketplace` | `ananddtyagi/cc-marketplace` | Community |
| `bills-claude-skills` | `BillChirico/bills-claude-skills` | Community |
| `superpowers-marketplace` | `obra/superpowers-marketplace` | Community |
| `obsidian-skills` | `kepano/obsidian-skills` | Community |
| `axton-obsidian-visual-skills` | `axtonliu/axton-obsidian-visual-skills` | Community |
| `visual-explainer-marketplace` | `nicobailon/visual-explainer` | Community |
| `bitwarden-marketplace` | `bitwarden/ai-plugins` | Community |
| `lunar-claude` | `basher83/lunar-claude` | Infrastructure |
| `claude-code-plugins-plus` | `jeremylongshore/claude-code-plugins-plus` | Infrastructure |
| `claude-code-workflows` | `wshobson/agents` | Infrastructure / Dev |
| `claude-skills` | `secondsky/claude-skills` | Dev Tools |
| `cc-dev-tools` | `Lucklyric/cc-dev-tools` | AI Integrations |
| `wakatime` | `wakatime/claude-code-wakatime` | Time Tracking |
| `openai-codex` | `openai/codex-plugin-cc` | AI Integrations |
| `browser-use-skills` | `browser-use/browser-use` | Synthetic |
| `fabric-patterns` | `danielmiessler/fabric` | Synthetic |

## Enabled Plugins by Category

### Official Anthropic — [`official.nix`](official.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `document-skills@anthropic-agent-skills` | enabled | xlsx, docx, pptx, pdf document creation |
| `commit-commands@claude-plugins-official` | enabled | Git commit workflows |
| `code-review@claude-plugins-official` | enabled | Code review |
| `pr-review-toolkit@claude-plugins-official` | enabled | PR review suite |
| `feature-dev@claude-plugins-official` | enabled | Feature development guidance |
| `security-guidance@claude-plugins-official` | enabled | Security guidance for infra work |
| `plugin-dev@claude-plugins-official` | enabled | Plugin development tools |
| `hookify@claude-plugins-official` | enabled | Hook creation from conversation analysis |
| `claude-code-setup@claude-plugins-official` | enabled | Claude Code setup and configuration |
| `claude-md-management@claude-plugins-official` | enabled | CLAUDE.md management |
| `pyright-lsp@claude-plugins-official` | enabled | Python type checking LSP |
| `typescript-lsp@claude-plugins-official` | disabled | Minimal TS usage |
| `ralph-loop@claude-plugins-official` | disabled | Superseded by native agent teams |

### External Third-Party — [`external.nix`](external.nix)

| Plugin | Status | Auth Required | Description |
| ------ | ------ | ------------- | ----------- |
| `github@claude-plugins-official` | enabled | `GITHUB_PERSONAL_ACCESS_TOKEN` | Repository, issues, PRs |
| `context7@claude-plugins-official` | enabled | Optional API key | Library documentation lookup |
| `playwright@claude-plugins-official` | enabled | Playwright installed | Browser automation and testing |
| `slack@claude-plugins-official` | enabled | Slack OAuth | Team communication |
| `asana@claude-plugins-official` | disabled | Asana API token | Task management |
| `linear@claude-plugins-official` | disabled | Linear API key | Issue tracking |
| `gitlab@claude-plugins-official` | disabled | GitLab API token | GitLab integration |
| `greptile@claude-plugins-official` | disabled | — | Removed: not worth cost |
| `firebase@claude-plugins-official` | disabled | Firebase credentials | Firebase platform |
| `supabase@claude-plugins-official` | disabled | Supabase API key | Supabase platform |
| `stripe@claude-plugins-official` | disabled | Stripe API key | Payment processing |
| `laravel-boost@claude-plugins-official` | disabled | Laravel project | Laravel framework |
| `serena@claude-plugins-official` | disabled | Serena API key | AI memory management |

### Community — [`community.nix`](community.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `analyze-issue@cc-marketplace` | enabled | GitHub issue analysis |
| `create-worktrees@cc-marketplace` | enabled | Git worktree creation |
| `python-expert@cc-marketplace` | enabled | Python expertise |
| `devops-automator@cc-marketplace` | enabled | CI/CD, cloud infra, deployment |
| `superpowers@superpowers-marketplace` | enabled | Comprehensive Claude enhancement suite |
| `superpowers-lab@superpowers-marketplace` | enabled | Experimental superpowers |
| `superpowers-developing-for-claude-code@superpowers-marketplace` | enabled | Plugin development superpowers |
| `obsidian@obsidian-skills` | enabled | 5 skills: markdown, bases, canvas, CLI, utilities |
| `obsidian-visual-skills@axton-obsidian-visual-skills` | enabled | 3 skills: Excalidraw, Mermaid, Canvas Creator |
| `visual-explainer@visual-explainer-marketplace` | enabled | 1 skill + 8 commands: HTML diagrams, diff reviews, slides |
| `claude-retrospective@bitwarden-marketplace` | enabled | 3 skills: retrospecting, session data, git analysis |
| `claude-config-validator@bitwarden-marketplace` | enabled | 1 skill: reviewing-claude-config |
| `browser-use@browser-use-skills` | enabled | Browser automation (requires `browser-use` via uv) |

### Infrastructure — [`infrastructure.nix`](infrastructure.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `proxmox-infrastructure@lunar-claude` | enabled | Proxmox VM/LXC management |
| `ansible-workflows@lunar-claude` | enabled | Ansible playbook workflows |
| `infrastructure-as-code-generator@claude-code-plugins-plus` | enabled | IaC generation |
| `terraform-module-builder@claude-code-plugins-plus` | enabled | Terraform module authoring |
| `cicd-automation@claude-code-workflows` | enabled | GitHub Actions CI/CD |

### Development — [`development.nix`](development.nix)

**Auto-discovered personal plugins (18):** All plugin directories in `JacobPEvans/claude-code-plugins`
are discovered at flake update time and enabled automatically as `*@jacobpevans-cc-plugins`:

`ai-delegation`, `code-standards`, `codeql-resolver`, `config-management`, `content-guards`,
`git-guards`, `git-standards`, `git-workflows`, `github-workflows`, `infra-orchestration`,
`infra-standards`, `pal-health`, `pr-lifecycle`, `process-cleanup`, `project-standards`,
`script-guards`, `session-analytics`, `skill-guards`

**Explicit plugins:**

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `backend-development@claude-code-workflows` | enabled | Python/Shell backend; multiple skills |
| `unit-testing@claude-code-workflows` | enabled | Unit test workflows |
| `tdd-workflows@claude-code-workflows` | enabled | TDD red/green/refactor cycle |
| `code-refactoring@claude-code-workflows` | enabled | Refactoring assistance |
| `codebase-cleanup@claude-code-workflows` | enabled | Dead code, cleanup |
| `agent-orchestration@claude-code-workflows` | enabled | Multi-agent coordination |
| `observability-monitoring@claude-code-workflows` | enabled | Distributed tracing, SLO |
| `python-development@claude-code-workflows` | enabled | Django/FastAPI with 5 specialized skills |
| `full-stack-orchestration@claude-code-workflows` | enabled | 7+ agent multi-agent workflows |
| `developer-essentials@claude-code-workflows` | enabled | Common dev tools and utilities |
| `performance-testing-review@claude-code-workflows` | enabled | Performance analysis, test coverage |
| `api-design-principles@claude-skills` | enabled | REST/GraphQL API design |
| `rest-api-design@claude-skills` | enabled | REST design patterns |
| `graphql-implementation@claude-skills` | enabled | GraphQL implementation |
| `websocket-implementation@claude-skills` | enabled | WebSocket patterns |
| `playwright@claude-skills` | enabled | Browser testing skills |
| `vitest-testing@claude-skills` | enabled | Vitest unit testing |
| `jest-generator@claude-skills` | enabled | Jest test generation |
| `vulnerability-scanning@claude-skills` | enabled | Security scanning |
| `csrf-protection@claude-skills` | enabled | CSRF protection patterns |
| `xss-prevention@claude-skills` | enabled | XSS prevention patterns |
| `recommendation-engine@claude-skills` | enabled | Recommendation systems |
| `sql-query-optimization@claude-skills` | enabled | SQL optimization |
| `better-auth@claude-skills` | enabled | Auth implementation |
| `oauth-implementation@claude-skills` | enabled | OAuth flows |

### Monitoring — [`monitoring.nix`](monitoring.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `claude-code-wakatime@wakatime` | enabled | Time tracking via WakaTime |

### Experimental — [`experimental.nix`](experimental.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `ralph-loop@claude-plugins-official` | enabled | Autonomous iteration loops (`/ralph-loop`, `/cancel-ralph`) |
| `codex@cc-dev-tools` | enabled | OpenAI GPT for high-reasoning coding (community) |
| `codex@openai-codex` | enabled | Official OpenAI Codex (`/codex:review`, `/codex:rescue`) |
| `gemini@cc-dev-tools` | enabled | Google Gemini with web search + session resumption |
| `telegram-notifier@cc-dev-tools` | disabled | Requires `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` |

### Fabric Patterns — [`fabric.nix`](fabric.nix)

| Plugin | Status | Description |
| ------ | ------ | ----------- |
| `fabric-patterns@fabric-patterns` | enabled | 32 curated patterns from danielmiessler/fabric |

Curated pattern list is in [`fabric-curated-patterns.json`](../fabric-curated-patterns.json).
See [`modules/fabric/README.md`](../../fabric/README.md) for full Fabric documentation.

## Synthetic Marketplaces

Three marketplaces lack native `.claude-plugin/` structure in their upstream repos. Nix wraps
them via derivations in [`marketplace-overrides.nix`](../marketplace-overrides.nix):

| Marketplace | Upstream Repo | Wrapping Strategy |
| ----------- | ------------- | ----------------- |
| `browser-use-skills` | `browser-use/browser-use` | Wraps upstream skills directory |
| `fabric-patterns` | `danielmiessler/fabric` | Wraps curated subset of 252+ patterns as individual skills |
| `jacobpevans-cc-plugins` | `JacobPEvans/claude-code-plugins` | Auto-generates `marketplace.json` from discovered `plugin.json` files |

## Adding a Plugin

1. Check if the marketplace exists in [`marketplaces.nix`](marketplaces.nix). If not, add it
   with the key matching the `name` field from the repo's `.claude-plugin/marketplace.json`.
2. Add `"plugin-name@marketplace-key" = true;` to the appropriate category `.nix` file.
3. Run `nix flake check` to validate.
4. Deploy with `darwin-rebuild switch` and verify in a live Claude Code session.
