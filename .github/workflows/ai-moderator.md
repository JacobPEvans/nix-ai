---
engine: copilot
imports:
  - githubnext/agentics/workflows/ai-moderator.md@main
on:
  roles: all
  issues:
    types: [opened]
    lock-for-agent: true
  issue_comment:
    types: [created]
    lock-for-agent: true
  pull_request:
    types: [opened]
    forks: "*"
  skip-roles: [admin, maintainer, write, triage]
  skip-bots: [github-actions, copilot]
permissions:
  contents: read
  issues: read
  pull-requests: read
---

# AI Moderator

Imported from upstream agentics.
