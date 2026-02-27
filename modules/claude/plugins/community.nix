# Community Marketplace Plugins
#
# Plugins from community-maintained marketplaces:
# - cc-marketplace: Official source for claudecodecommands.directory plugins
# - superpowers-marketplace: Enhanced Claude capabilities (obra/Jesse Vincent)

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

    # REMOVED - redundant or unused:
    # double-check - unnecessary
    # infrastructure-maintainer - too generic
    # monitoring-observability-specialist - splunk repos don't need this
    # awesome-claude-code-plugins - AGGREGATION, use true source (cc-marketplace) instead
  };
}
