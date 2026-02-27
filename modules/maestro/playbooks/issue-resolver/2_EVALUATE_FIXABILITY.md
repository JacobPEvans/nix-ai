# Evaluate Fixability

Score and categorize each issue for autonomous resolution.

## Context

Loop iteration: {{LOOP_NUMBER}}

## Scoring Criteria

Award points for:

- **+3**: Clear reproduction steps or acceptance criteria
- **+2**: Labels include `bug`, `enhancement`, or `documentation`
- **+2**: Issue body length > 100 characters (well-described)
- **+1**: Issue created in last 30 days (recent)
- **-2**: Labels include `complex`, `needs-discussion`, `help-wanted`
- **-3**: Issue mentions "breaking change" or "major refactor"

## Tasks

- [ ] Read `issues.json` from previous step
- [ ] Score each issue using criteria above
- [ ] Categorize: `quick-fix` (score >= 5), `standard` (3-4), `complex` (< 3)
- [ ] Write scored issues to `scored-issues.json`

## Output

Creates `scored-issues.json`:

```json
[
  {"number": 123, "title": "...", "score": 7, "category": "quick-fix"}
]
```
