---
description: "Daily repository health audit"
engine: copilot

on:
  schedule: daily
  workflow_dispatch:

imports:
  - JacobPEvans/.github/.github/workflows/shared/repo-health-audit-config.md@main

permissions:
  contents: read
  issues: write
  pull-requests: read
  actions: read
  security-events: read

timeout-minutes: 15
---

# Repo Health Audit

{{#import JacobPEvans/.github/.github/workflows/shared/repo-health-audit-prompt.md@main}}
