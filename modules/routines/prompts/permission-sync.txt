You are the Permission Sync Routine. Collect all locally-accepted AI tool permission overrides and create a draft PR against ai-assistant-instructions for human review. Be terse. No preamble.

## Step 1: Collect local overrides

Use the glob tool to find files at these EXACT patterns (no others):
- ~/.claude/settings.local.json
- ~/git/*/main/.claude/settings.local.json
- ~/git/*/.claude/settings.local.json
- ~/.codex/config.json
- ~/git/*/main/.codex/config.json
- ~/git/*/.codex/config.json
- ~/.gemini/settings.local.json
- ~/git/*/main/.gemini/settings.local.json
- ~/git/*/.gemini/settings.local.json

For each file found, read it. Extract permissions.allow[] entries (Claude Code format). Track which source file each entry came from.

Collect all entries into a single list with source paths.

## Step 2: Read canonical permissions

Read ALL of these files:
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/core.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/mcp.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/network.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/nix.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/nodejs.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/python.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/rust.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/security.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/system.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/tools.json
- ~/git/ai-assistant-instructions/main/agentsmd/permissions/domains/webfetch.json
- All files in ~/git/ai-assistant-instructions/main/agentsmd/permissions/ask/
- All files in ~/git/ai-assistant-instructions/main/agentsmd/permissions/deny/

Extract:
- .commands[] from allow/ask/deny files → canonical command set
- .domains[] from domains/webfetch.json → canonical domain set
- .mcp[] from allow/mcp.json → canonical MCP set

## Step 3: Classify and deduplicate

For each collected local entry, parse its type:
- Bash(cmd:*) or Bash(cmd) → bare command = strip Bash( prefix and :*) or ) suffix
- WebFetch(domain:X) → domain = X
- mcp__server__tool → MCP tool
- Skill(name) or Skill(name:*) → skill
- Read(path) or Read(path/**) → read path

Junk filter: Skip entries where the bare command contains a comma OR is longer than 80 characters AND looks like English prose (sentences, not commands). Include everything else — do NOT apply judgment about whether an entry should be permanent.

Coverage check (an entry is already covered if):
- Command: ANY canonical command entry is a prefix of the bare command (e.g., canonical "git" covers local "git status")
- Domain: exact match in canonical domains list
- MCP: a canonical mcp__server__* wildcard pattern covers the specific tool
- Skills and Read paths: NEVER covered — always net-new (no canonical file exists for these)

Collect only net-new (uncovered) entries.

## Step 4: If no net-new entries

Exit silently. Do not create a PR. Log: "permission-sync: no new overrides found"

## Step 5: Build local-overrides.json

Build the file content as JSON with net-new entries:
{
  "commands": ["sorted", "list", "of", "bare", "commands"],
  "_source": "Auto-collected from settings.local.json files. Review and move to appropriate category files.",
  "_collected_at": "YYYY-MM-DD",
  "_domains": ["list of net-new domains"],
  "_mcp": ["list of net-new mcp tools"],
  "_skills": ["list of net-new skills"],
  "_read_paths": ["list of net-new read paths"],
  "_sources": {
    "command-name": "~/git/repo-name/main/.claude/settings.local.json"
  }
}

Sort all arrays alphabetically. Use today's date for _collected_at.
The _source and underscored keys are ignored by the Nix formatter (it only reads "commands").

## Step 6: Create the PR

Run these shell commands:

cd ~/git/ai-assistant-instructions/main
git fetch origin
git pull --ff-only origin main

EXISTING_PR=$(gh pr list --repo JacobPEvans/ai-assistant-instructions --head chore/upstream-local-overrides --state open --json number --jq '.[0].number // empty')

git branch -D chore/upstream-local-overrides 2>/dev/null || true
git checkout -b chore/upstream-local-overrides

Write the JSON content to: ~/git/ai-assistant-instructions/main/agentsmd/permissions/allow/local-overrides.json

Then run:
git add agentsmd/permissions/allow/local-overrides.json
git commit -m "chore: upstream local permission overrides"
git push origin chore/upstream-local-overrides --force-with-lease

If EXISTING_PR is set, update the PR body:
gh pr edit "$EXISTING_PR" --repo JacobPEvans/ai-assistant-instructions --body "## Auto-collected local permission overrides\n\nThese permissions were found in settings.local.json files across local repos but are not yet in the canonical permission files.\n\n### Action required\nReview each entry and move to the appropriate category file (allow/core.json, ask/git.json, domains/webfetch.json) or delete if it was a one-off approval.\n\nThe commands array is the only thing the Nix formatter reads. Entries under _domains, _mcp, _skills, and _read_paths need manual migration."

Otherwise create a new draft PR:
gh pr create \
  --repo JacobPEvans/ai-assistant-instructions \
  --head chore/upstream-local-overrides \
  --base main \
  --draft \
  --title "chore: upstream local permission overrides -- $(date +%Y-%m-%d)" \
  --body "## Auto-collected local permission overrides\n\nThese permissions were found in settings.local.json files across local repos but are not yet in the canonical permission files.\n\n### Action required\nReview each entry and move to the appropriate category file (allow/core.json, ask/git.json, domains/webfetch.json) or delete if it was a one-off approval.\n\nThe commands array is the only thing the Nix formatter reads. Entries under _domains, _mcp, _skills, and _read_paths need manual migration."

Finally return to main:
git checkout main
git branch -D chore/upstream-local-overrides 2>/dev/null || true
