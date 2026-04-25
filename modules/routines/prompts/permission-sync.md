# Permission Sync Routine

Find AI-tool permissions accepted locally but not yet upstreamed, and open a
draft PR against `ai-assistant-instructions` for human review. Be terse.

## Inputs

- **Local overrides**: any `settings.local.json` (Claude, Gemini) or `config.json` (Codex)
  under `~` and under `~/git/**`. Glob recursively; don't enumerate paths.
- **Canonical set**: every JSON file under
  `~/git/ai-assistant-instructions/main/agentsmd/permissions/` (allow, ask, deny, domains).
  Read whatever is there — the directory layout may grow.

## What to extract

From each local override, pull `permissions.allow[]` (Claude format).
From each canonical file, pull `commands[]`, `domains[]`, and `mcp[]` as applicable.

Classify each local entry by prefix:

| Pattern                  | Type         |
| ------------------------ | ------------ |
| `Bash(cmd)` / `Bash(cmd:*)` | command (strip wrapper) |
| `WebFetch(domain:X)`     | domain       |
| `mcp__server__tool`      | mcp tool     |
| `Skill(name)`            | skill        |
| `Read(path)`             | read path    |

**Junk filter**: drop entries that look like English prose (have a comma or
exceed 80 chars AND read as a sentence). Otherwise keep — don't editorialize.

**Coverage**: an entry is already canonical if any canonical command is a prefix
of the local bare command, or if a domain/mcp matches exactly (or via wildcard).
Skills and read paths are never covered — always net-new.

## Output

If no net-new entries: log `permission-sync: no new overrides found` and exit.

Otherwise write `agentsmd/permissions/allow/local-overrides.json` in the
ai-assistant-instructions checkout:

```json
{
  "_source": "Auto-collected from local settings. Review and migrate.",
  "_collected_at": "YYYY-MM-DD",
  "commands": [],
  "_domains": [],
  "_mcp": [],
  "_skills": [],
  "_read_paths": [],
  "_sources": { "entry": "path/to/source.json" }
}
```

Sort arrays. Only `commands` is consumed by the Nix formatter; the underscored
keys are review hints for the human.

## Delivery

Open or update a draft PR on `JacobPEvans/ai-assistant-instructions`, branch
`chore/upstream-local-overrides`, base `main`. Title:
`chore: upstream local permission overrides -- YYYY-MM-DD`.

Body should explain the file is auto-generated and entries need to be migrated
into the appropriate category file (or deleted if one-off). Reuse the existing
PR if one is open on that branch — don't open duplicates.
