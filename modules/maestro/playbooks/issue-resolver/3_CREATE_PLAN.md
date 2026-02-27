# Create Plan

Select the highest-priority fixable issue and create an implementation plan.

## Context

Loop iteration: {{LOOP_NUMBER}}

## Selection Criteria

1. Prefer `quick-fix` category over others
2. Within same category, prefer higher score
3. Skip issues already being worked on (check for linked PRs)

## Tasks

- [ ] Read `scored-issues.json`
- [ ] Sort by category priority, then score (descending)
- [ ] Extract top issue number: `ISSUE_NUMBER=$(jq -r '.[0].number' scored-issues.json)`
- [ ] For top issue, check: `gh pr list --search "fixes #$ISSUE_NUMBER"`
- [ ] If PR exists, skip to next issue
- [ ] Write selected issue to `selected-issue.json`

## Output

Creates `selected-issue.json`:

```json
{"number": 123, "title": "...", "body": "...", "category": "quick-fix"}
```

If no suitable issue found, create `no-issue-selected.json` with reason.
