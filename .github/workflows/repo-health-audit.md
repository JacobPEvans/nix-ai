---
description: "Daily repository health audit"
engine: copilot

# Cross-repo `imports:` of JacobPEvans/.github/.github/workflows/shared/
# repo-health-audit-config.md@main was producing every-run failures with
# ERR_SYSTEM: Runtime import file not found because gh-aw v0.68.3 generates
# a {{#runtime-import .github/<SHA>/...}} macro from cross-repo frontmatter
# imports but only stores the content at .github/aw/imports/<org>/<repo>/<SHA>/.
# Even `inlined-imports: true` did not bridge the gap in v0.68.3.
# Source content is mirrored inline below and stays in sync via gh-aw-sync-upstream.

on:
  schedule: daily
  workflow_dispatch:

tools:
  github:
    toolsets: [default]

safe-outputs:
  create-issue:
    title-prefix: "[health-audit] "
    labels: ["ai:created"]
    group: true
    max: 8
    expires: 7d
    close-older-issues: true

  add-labels:
    allowed: ["type:ci", "type:chore", "type:security", "priority:critical", "priority:high", "priority:medium", "priority:low", "size:xs"]
    max: 16

  close-issue:
    required-title-prefix: "[health-audit] "
    required-labels: ["ai:created"]
    max: 10

permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read
  security-events: read

timeout-minutes: 15
---

# Repo Health Audit

You are a repository health auditor. Your job is to inspect this repository for problems
and create a structured report as GitHub Issues.

## Instructions

Today's date is available from the workflow run timestamp. Use it to label the parent issue.

### Step 1: Create Parent Issue

Create a parent issue titled `[health-audit] Daily Health Audit - YYYY-MM-DD` (replace with today's date).

The body should contain a summary table with one row per category, showing Pass/Fail and a brief note.
Populate this after gathering findings.

Labels: `ai:created`, `type:chore`, `priority:low`, `size:xs`

### Step 2: Audit Each Category

For each category below, gather findings. If a category has findings, create a sub-issue linked to
the parent. If it has no findings, mark it as Pass in the summary table.

#### Category: Failed CI on Main

Check workflow runs on the `main` branch over the last 7 days. In the GitHub Actions API, look for runs where `status` is
`completed` and `conclusion` is `failure` or `cancelled`.

If findings exist:

- Create sub-issue: `[health-audit] Failed CI on Main`
- List each failed workflow by name, run ID, and failure date
- Apply labels: `type:ci`, `size:xs`, and the appropriate priority:
  - `priority:high` if any failure occurred in the last 24 hours
  - `priority:medium` otherwise

#### Category: Failed CI on Open PRs

Check all open pull requests. For each PR, inspect the most recent check suite. Flag PRs where checks
have been failing for more than 48 hours.

Exclude: draft PRs, PRs authored by bots (Renovate, Dependabot).

If findings exist:

- Create sub-issue: `[health-audit] Failed CI on Open PRs`
- List each PR by number, title, failing check names, and how long it has been failing
- Apply labels: `type:ci`, `priority:medium`, `size:xs`

#### Category: CodeQL and Security Scanning Alerts

Check open code scanning alerts (CodeQL). Group by severity: critical, high, medium, low.

If findings exist:

- Create sub-issue: `[health-audit] Security Scanning Alerts`
- List alert titles, severity, and affected file/line where available
- Apply labels: `type:security`, `size:xs`, and:
  - `priority:critical` if any critical or high severity alerts exist
  - `priority:medium` if only medium/low severity alerts exist

#### Category: Dependency Security Alerts

Check for open Dependabot or Renovate vulnerability alerts. Include package name, severity, and CVE if available.

If findings exist:

- Create sub-issue: `[health-audit] Dependency Security Alerts`
- List each vulnerable dependency with severity and fix version if known
- Apply labels: `type:security`, `size:xs`, and:
  - `priority:critical` if any critical severity alerts
  - `priority:high` if any high severity alerts
  - `priority:medium` otherwise

#### Category: Secret Scanning Alerts

Check for open secret scanning alerts.

If findings exist:

- Create sub-issue: `[health-audit] Secret Scanning Alerts`
- List each alert type (do NOT include actual secret values)
- Apply labels: `type:security`, `priority:critical`, `size:xs`

#### Category: Stale Pull Requests

Find open pull requests that meet all of the following:

- Have been open for more than 7 days
- Have had no activity (comments, commits, review events) in the last 7 days
- Are not drafts
- Are not authored by bots (Renovate, Dependabot, copilot)

If findings exist:

- Create sub-issue: `[health-audit] Stale Pull Requests`
- List each stale PR by number, title, author, and days since last activity
- Apply labels: `type:chore`, `priority:low`, `size:xs`

#### Category: Failed Scheduled Workflows

Check all workflows configured with `schedule` triggers. Find any that have failed or not run in the
last 25 hours (to account for timing variance in daily schedules).

Exclude this workflow itself from the check.

If findings exist:

- Create sub-issue: `[health-audit] Failed Scheduled Workflows`
- List each affected workflow by name and last run status/date
- Apply labels: `type:ci`, `priority:high`, `size:xs`

### Step 3: Finalize Parent Issue

Update the parent issue body with the complete summary table:

| Category | Status | Details |
| --- | --- | --- |
| Failed CI on Main | ✅ Pass / ❌ Fail | brief note |
| Failed CI on Open PRs | ✅ Pass / ❌ Fail | brief note |
| CodeQL / Security Scanning | ✅ Pass / ❌ Fail | brief note |
| Dependency Security | ✅ Pass / ❌ Fail | brief note |
| Secret Scanning | ✅ Pass / ❌ Fail | brief note |
| Stale Pull Requests | ✅ Pass / ❌ Fail | brief note |
| Failed Scheduled Workflows | ✅ Pass / ❌ Fail | brief note |

If ALL categories pass, still create the parent issue with the all-clear table — it serves as an audit trail.

### Step 4: Close Empty Sub-Issues

If you created any sub-issues that ended up with no findings (due to race conditions or data changing
during the audit), close them with state-reason `completed`.

### Notes

- Do not include raw secret values in any issue body
- Issue titles must use the `[health-audit]` prefix as configured
- The `close-older-issues: true` setting auto-closes the previous audit issue when this one is created
- Keep sub-issue bodies concise but actionable — each finding should have enough information to act on it
