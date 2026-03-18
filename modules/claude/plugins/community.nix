# Community Marketplace Plugins
#
# Plugins from community-maintained marketplaces:
# - cc-marketplace: Official source for claudecodecommands.directory plugins
# - superpowers-marketplace: Enhanced Claude capabilities (obra/Jesse Vincent)
# - bitwarden-marketplace: Enterprise-grade session analysis and config validation

_:

{
  enabledPlugins = {
    # CC Marketplace - essential tools (official source for claudecodecommands.directory)
    "analyze-issue@cc-marketplace" = true;
    "create-worktrees@cc-marketplace" = true;
    "python-expert@cc-marketplace" = true; # User actively uses Python
    "devops-automator@cc-marketplace" = true; # CI/CD, cloud infra, monitoring, deployment

    # Superpowers - comprehensive Claude enhancement suite
    "superpowers@superpowers-marketplace" = true;
    "double-shot-latte@superpowers-marketplace" = true; # User requested restore
    "superpowers-lab@superpowers-marketplace" = true; # User requested add
    "superpowers-developing-for-claude-code@superpowers-marketplace" = true; # User requested restore

    # Obsidian Skills - Canonical (kepano/obsidian-skills)
    # Marketplace declares single plugin "obsidian" bundling 5 skills
    "obsidian@obsidian-skills" = true;

    # Obsidian Visual Skills - Diagrams (axtonliu/axton-obsidian-visual-skills)
    # Marketplace declares single plugin "obsidian-visual-skills" bundling 3 skills
    "obsidian-visual-skills@axton-obsidian-visual-skills" = true;

    # Bitwarden Marketplace - Enterprise-grade session analysis and config validation
    # claude-retrospective: 3 skills (retrospecting, extracting-session-data, analyzing-git-sessions)
    # claude-config-validator: 1 skill (reviewing-claude-config) — security + quality validation
    "claude-retrospective@bitwarden-marketplace" = true;
    "claude-config-validator@bitwarden-marketplace" = true;
    # NOT enabled - Bitwarden-specific: bitwarden-code-review, bitwarden-software-engineer,
    # bitwarden-security-engineer, bitwarden-product-analyst, bitwarden-init,
    # atlassian-reader, bitwarden-atlassian-tools

    # REMOVED - redundant or unused:
    # double-check - unnecessary
    # infrastructure-maintainer - too generic
    # monitoring-observability-specialist - splunk repos don't need this
    # awesome-claude-code-plugins - AGGREGATION, use true source (cc-marketplace) instead
  };
}
