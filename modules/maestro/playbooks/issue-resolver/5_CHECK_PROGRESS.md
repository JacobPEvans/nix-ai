# Check Progress

Verify the PR was created and determine if the loop should continue.

## Context

Loop iteration: {{LOOP_NUMBER}}

## Tasks

- [ ] Read `pr-created.json` (if exists)
- [ ] Extract PR number: `PR_NUMBER=$(jq -r '.pr_number' pr-created.json)`
- [ ] Verify PR exists: `gh pr view "$PR_NUMBER" --json state`
- [ ] If PR state is `OPEN` or `MERGED`, mark success
- [ ] Clean up temporary files: `issues.json`, `scored-issues.json`, `selected-issue.json`, `pr-created.json`
- [ ] Write run summary with current iteration number in filename

## Run Summary

Creates `LOOP_{{LOOP_NUMBER}}_SUMMARY.json`:

```json
{
  "status": "success",
  "issue_number": 123,
  "pr_number": 456,
  "repository": "owner/repo",
  "timestamp": "2026-01-18T10:00:00Z",
  "loop_iteration": {{LOOP_NUMBER}}
}
```

## Loop Control

- [ ] Check if more fixable issues remain in the repository
- [ ] Determine if another loop iteration is needed

Reset: ON
