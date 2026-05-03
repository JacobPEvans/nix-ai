# Marketplace: claude-code-workflows
# Source: github.com/wshobson/agents
# Stars (verified 2026-05-02): 34640
# Priority Tier: 4 (Community — highest popularity)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are PREFERRED over: Tier 5 only.
#   Variants from this marketplace are SUPERSEDED by:  Tiers 1, 2, 3.
#
# This is the most popular community plugin marketplace by GitHub stars among
# Tier 4 sources, so when two Tier 4 marketplaces ship the same role we
# generally prefer this one — UNLESS a higher-tier (1–3) variant exists, in
# which case the higher-tier wins and the corresponding plugin here is disabled.
#
# Per-plugin notes annotate which agents are duplicates of higher-tier variants
# and where the keeper lives.

_:

{
  enabledPlugins = {
    # ========================================================================
    # Backend / Frameworks (kept — many unique agents)
    # ========================================================================
    # Agents: backend-architect, event-sourcing-architect, graphql-architect,
    #         performance-engineer (DUP — keeper observability-monitoring),
    #         security-auditor (DUP — keeper full-stack-orchestration BUT
    #                           full-stack disabled below; remaining variant
    #                           is here, also code-review@claude-plugins-official
    #                           covers most security review needs Tier 1),
    #         tdd-orchestrator (KEEPER for this role at Tier 4),
    #         temporal-python-pro, test-automator (DUP — keeper unit-testing).
    "backend-development@claude-code-workflows" = true;

    # Agents: django-pro, fastapi-pro, python-pro (all unique).
    "python-development@claude-code-workflows" = true;

    # Agents: monorepo-architect (unique).
    "developer-essentials@claude-code-workflows" = true;

    # ========================================================================
    # Testing (selective)
    # ========================================================================
    # Agents: debugger (unique), test-automator (KEEPER for this role).
    # Best-judgement keeper among 5 community test-automator dups: this one
    # has the most direct name match for general unit-testing work.
    "unit-testing@claude-code-workflows" = true;

    # DISABLED — code-reviewer (DUP, superseded by Tier 1 pr-review-toolkit:code-reviewer)
    #            tdd-orchestrator (DUP — keeper backend-development:tdd-orchestrator).
    # Whole plugin offers nothing not covered by higher-tier or kept-Tier-4 plugins.
    "tdd-workflows@claude-code-workflows" = false;

    # DISABLED — code-reviewer (DUP, superseded by Tier 1 pr-review-toolkit:code-reviewer)
    #            legacy-modernizer (rarely used).
    "code-refactoring@claude-code-workflows" = false;

    # DISABLED — code-reviewer + test-automator both DUP. Loses deps-audit/
    # tech-debt/refactor-clean skills, which is acceptable for token savings.
    "codebase-cleanup@claude-code-workflows" = false;

    # DISABLED — ALL agents are duplicates: deployment-engineer (keeper
    # cicd-automation), performance-engineer (keeper observability-monitoring),
    # security-auditor (DUP), test-automator (keeper unit-testing).
    "full-stack-orchestration@claude-code-workflows" = false;

    # DISABLED — performance-engineer + test-automator both DUP.
    "performance-testing-review@claude-code-workflows" = false;

    # ========================================================================
    # Orchestration & Observability (kept — unique agents)
    # ========================================================================
    # Agents: context-manager (unique).
    "agent-orchestration@claude-code-workflows" = true;

    # Agents: database-optimizer (unique), network-engineer (unique),
    #         observability-engineer (unique), performance-engineer (KEEPER
    #         for this role across 4 community variants — best domain fit).
    "observability-monitoring@claude-code-workflows" = true;

    # ========================================================================
    # Cloud / DevOps
    # ========================================================================
    # Agents: cloud-architect (unique), deployment-engineer (KEEPER — keeper
    #         for this role; full-stack-orchestration variant disabled above),
    #         devops-troubleshooter, kubernetes-architect, terraform-specialist
    #         (all unique).
    "cicd-automation@claude-code-workflows" = true;
  };
}
