---
name: retrospective-report-location
description: This rule should be applied when using the claude-retrospective plugin's "retrospecting" skill, running "/retrospecting", or generating retrospective reports. Overrides the default per-project report output path to use a centralized location.
alwaysApply: false
globs:
  - "**/retrospecting/**"
  - "**/.claude/skills/retrospecting/**"
---

# Retrospective Report Location

When using the claude-retrospective plugin's `retrospecting` skill, always write
retrospective reports to `~/.claude/skills/retrospecting/reports/` instead of
`${CLAUDE_PROJECT_DIR}/.claude/skills/retrospecting/reports/`.

This ensures reports are centralized across all projects rather than scattered
in each project's `.claude/` directory.
