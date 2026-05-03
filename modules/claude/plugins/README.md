# Claude Code Plugin Catalog

Reference for all plugin marketplaces and enabled plugins managed by this module.

Parent doc: [`modules/claude/README.md`](../README.md)

## How Plugins Work

Plugins are referenced as `"plugin-name@marketplace-name"` pairs. Most marketplaces are
GitHub repos containing a `.claude-plugin/marketplace.json` manifest; synthetic
marketplaces (see bottom) are adapted via Nix derivations without requiring the native
structure. Nix pins every marketplace as a flake input for reproducible deployments.
Setting a plugin to `true` enables it; `false` keeps it visible but disabled.

## Priority Tier System

Files in this directory are organized **one-per-marketplace** with a `tierN-` prefix.
The tier number governs duplicate-resolution: when two plugins from different
marketplaces ship the same agent or skill, keep the **higher-tier** variant and
disable the lower-tier one. Document each disable inline with a reason.

| Tier | Source | Marketplaces |
| ---- | ------ | ------------ |
| **1** | Anthropic Official | `claude-plugins-official`, `anthropic-agent-skills` |
| **2** | First-party AI/cloud vendors | `openai-codex`, MCP integrations under `claude-plugins-official/external_plugins/*` |
| **3** | Personal | `jacobpevans-cc-plugins` |
| **4** | Community by GitHub-stars popularity (verified at edit time) | `claude-code-workflows` (34k★), `superpowers-marketplace` (925★), `cc-marketplace` (679★), `claude-skills` (129★) |
| **5** | Niche / specialty | `lunar-claude`, `claude-code-plugins-plus`, `bitwarden-marketplace`, `cc-dev-tools`, `fabric-patterns`, `huggingface-skills`, `obsidian-skills`, `axton-obsidian-visual-skills`, `visual-explainer-marketplace`, `browser-use-skills`, `vct-cribl-pack-validator-skills`, `wakatime` |

**Star counts are verified at edit time** via `gh repo view <owner>/<repo> --json
stargazerCount` and embedded in each tier file's header. Re-verify yearly or when
significantly reorganizing tiers.

## Marketplaces

All registered marketplaces, defined in [`marketplaces.nix`](marketplaces.nix). The
"Tier" column matches the priority system above.

| Key | GitHub | Stars (2026-05-02) | Tier |
| --- | ------ | -----------------: | ---- |
| `anthropic-agent-skills` | `anthropics/skills` | 127235 | 1 |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | 18410 | 1 / 2 |
| `openai-codex` | `openai/codex-plugin-cc` | 17071 | 2 |
| `jacobpevans-cc-plugins` | `JacobPEvans/claude-code-plugins` | 2 | 3 |
| `claude-code-workflows` | `wshobson/agents` | 34640 | 4 |
| `superpowers-marketplace` | `obra/superpowers-marketplace` | 925 | 4 |
| `cc-marketplace` | `ananddtyagi/cc-marketplace` | 679 | 4 |
| `claude-skills` | `secondsky/claude-skills` | 129 | 4 |
| `browser-use-skills` | `browser-use/browser-use` (synthetic) | 91681 | 5 |
| `fabric-patterns` | `danielmiessler/fabric` (synthetic) | 41428 | 5 |
| `obsidian-skills` | `kepano/obsidian-skills` | 28277 | 5 |
| `huggingface-skills` | `huggingface/skills` | 10371 | 5 |
| `visual-explainer-marketplace` | `nicobailon/visual-explainer` | 7816 | 5 |
| `axton-obsidian-visual-skills` | `axtonliu/axton-obsidian-visual-skills` | 2651 | 5 |
| `claude-code-plugins-plus` | `jeremylongshore/claude-code-plugins-plus` | 2083 | 5 |
| `bitwarden-marketplace` | `bitwarden/ai-plugins` | 90 | 5 |
| `wakatime` | `wakatime/claude-code-wakatime` | 73 | 5 |
| `cc-dev-tools` | `Lucklyric/cc-dev-tools` | 29 | 5 |
| `lunar-claude` | `basher83/lunar-claude` | 18 | 5 |
| `vct-cribl-pack-validator-skills` | `VisiCore/vct-cribl-pack-validator` (synthetic) | 0 | 5 |
| `bills-claude-skills` | `BillChirico/bills-claude-skills` (registered, no plugins enabled) | — | — |

`claude-plugins-official` is split across Tier 1 (Anthropic-authored core plugins
in `tier1-claude-plugins-official.nix`) and Tier 2 (first-party MCP integrations
to GitHub/Slack/Stripe/etc. in `tier2-external-mcp-integrations.nix`).

## Duplicate Resolution Rule

When the same role (e.g., `code-reviewer`, `test-automator`, `playwright`) ships
from multiple plugins:

1. **Keep** the variant from the highest-tier marketplace.
2. **Disable** the lower-tier duplicate(s) by setting `false` in their tier file.
3. **Inline-comment** the disable line with a reason citing the keeper's tier and
   marketplace, e.g.:

   ```nix
   "playwright@claude-skills" = false; # Superseded by Tier 2 playwright@claude-plugins-official.
   ```

4. If you can't disable a plugin (because it bundles unique agents alongside the
   duplicate), keep it enabled and **document the tolerated duplicate** in the
   file's plugin comment block — see `tier4-claude-code-workflows.nix` for the
   `backend-development` example (kept for `python-pro`/`fastapi-pro` despite a
   duplicate `test-automator`).
5. Within the same tier, prefer the marketplace with higher GitHub stars; fall
   back to best judgement if the gap is small.

## File Layout

```text
plugins/
├── default.nix                              # imports + merge
├── marketplaces.nix                         # marketplace definitions (one entry per repo)
├── README.md                                # this file
│
├── tier1-claude-plugins-official.nix        # Anthropic core
├── tier1-anthropic-agent-skills.nix         # Anthropic skills (xlsx/docx/pdf/pptx)
│
├── tier2-openai-codex.nix                   # Official OpenAI codex plugin
├── tier2-external-mcp-integrations.nix      # GitHub/Slack/Context7/Stripe/etc.
│
├── tier3-jacobpevans-cc-plugins.nix         # Auto-discovered personal plugins
│
├── tier4-claude-code-workflows.nix          # wshobson/agents (34k★)
├── tier4-superpowers-marketplace.nix        # obra/superpowers (925★)
├── tier4-cc-marketplace.nix                 # ananddtyagi/cc-marketplace (679★)
├── tier4-claude-skills.nix                  # secondsky/claude-skills (129★)
│
├── tier5-lunar-claude.nix                   # ansible/proxmox infra
├── tier5-claude-code-plugins-plus.nix       # terraform/iac
├── tier5-bitwarden-marketplace.nix          # claude-retrospective, config-validator
├── tier5-cc-dev-tools.nix                   # codex (community), gemini, telegram
├── tier5-fabric-patterns.nix                # daniel miessler patterns (synthetic)
├── tier5-huggingface-skills.nix             # hf-cli
├── tier5-obsidian-skills.nix
├── tier5-axton-obsidian-visual-skills.nix
├── tier5-visual-explainer-marketplace.nix
├── tier5-browser-use-skills.nix             # synthetic
├── tier5-vct-cribl-pack-validator-skills.nix # synthetic
└── tier5-wakatime.nix
```

## Adding a New Marketplace

1. Add the marketplace entry to [`marketplaces.nix`](marketplaces.nix) with the
   key matching the `name` field from the repo's `.claude-plugin/marketplace.json`.
2. Verify popularity: `gh repo view <owner>/<repo> --json stargazerCount`.
3. Decide tier:
   - Anthropic official → Tier 1
   - First-party AI vendor (OpenAI, Google, GitHub-as-vendor) → Tier 2
   - Personal repos → Tier 3
   - Community marketplace with broad scope (>500 stars, multiple plugins) → Tier 4
   - Single-purpose / specialty / synthetic / low-popularity → Tier 5
4. Create `tierN-<marketplace-name>.nix` using the standard header (copy from any
   existing tier file).
5. Add the import + merge entry to `default.nix`.
6. Run `nix flake check`.

## Adding a Plugin

1. Open the marketplace's tier file.
2. Add `"plugin-name@marketplace-key" = true;` (or `false` to disable).
3. **If a duplicate exists in a higher tier**: don't enable it — leave it `false`
   with an inline comment pointing at the keeper.
4. Run `nix flake check`.

## Synthetic Marketplaces

Three marketplaces lack native `.claude-plugin/` structure in their upstream repos.
Nix wraps them via derivations in [`marketplace-overrides.nix`](../marketplace-overrides.nix):

| Marketplace | Upstream Repo | Wrapping Strategy |
| ----------- | ------------- | ----------------- |
| `browser-use-skills` | `browser-use/browser-use` | Wraps upstream skills directory |
| `vct-cribl-pack-validator-skills` | `VisiCore/vct-cribl-pack-validator` | Wraps bare `.claude/skills/` layout |
| `fabric-patterns` | `danielmiessler/fabric` | Wraps curated subset of 252+ patterns as individual skills |
| `jacobpevans-cc-plugins` | `JacobPEvans/claude-code-plugins` | Auto-generates `marketplace.json` from discovered `plugin.json` files |

## Token-Cost Awareness

Every enabled plugin contributes its skill descriptions and agent metadata to the
**eager** session-start context (typically 50-200 tokens per plugin). Even disabled
plugins listed in `enabledPlugins: { name: false }` are free — only `true` plugins
load. **Reduce per-session overhead** by:

1. Disabling lower-tier duplicates (this directory's primary mechanism).
2. Committing per-repo `.claude/settings.json` overrides into individual project
   repositories to disable plugins that aren't relevant to that repo's stack.
3. Verifying `ENABLE_TOOL_SEARCH = "auto:10"` in `modules/claude/settings.nix`
   so MCP schemas defer until needed.

See [`docs/architecture/token-optimization.md`](../../../docs/architecture/token-optimization.md)
for the full rationale and per-session measurements (if it exists; otherwise consult
the user-level plan file at `~/.claude/plans/`).
