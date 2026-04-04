---
description: Override report output path when using the claude-retrospective retrospecting skill
---

# Retrospective Report Location

When using the claude-retrospective plugin's `retrospecting` skill, always write
retrospective reports to `~/.claude/skills/retrospecting/reports/` instead of
`${CLAUDE_PROJECT_DIR}/.claude/skills/retrospecting/reports/`.

This ensures reports are centralized across all projects rather than scattered
in each project's `.claude/` directory.
