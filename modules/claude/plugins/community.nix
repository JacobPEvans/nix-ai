# Community Marketplace Plugins
#
# Plugins from community-maintained marketplaces:
# - cc-marketplace: Official source for claudecodecommands.directory plugins
# - superpowers-marketplace: Enhanced Claude capabilities (obra/Jesse Vincent)
# - visual-explainer-marketplace: Rich HTML diagrams, diff reviews, slides (nicobailon)
# - bitwarden-marketplace: Enterprise-grade session analysis and config validation
# - browser-use-skills: Browser automation (synthetic marketplace — repo lacks native structure)

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

    # Visual Explainer - HTML diagrams, diff reviews, plan audits, slides, data tables
    # Marketplace declares single plugin "visual-explainer" with 1 skill + 8 commands
    "visual-explainer@visual-explainer-marketplace" = true;

    # Bitwarden Marketplace - Enterprise-grade session analysis and config validation
    # claude-retrospective: 3 skills (retrospecting, extracting-session-data, analyzing-git-sessions)
    # claude-config-validator: 1 skill (reviewing-claude-config) — security + quality validation
    "claude-retrospective@bitwarden-marketplace" = true;
    "claude-config-validator@bitwarden-marketplace" = true;
    # NOT enabled - Bitwarden-specific: bitwarden-code-review, bitwarden-software-engineer,
    # bitwarden-security-engineer, bitwarden-product-analyst, bitwarden-init,
    # atlassian-reader, bitwarden-atlassian-tools

    # Browser Automation - browser-use (synthetic marketplace — repo lacks native structure)
    # Bundles 4 skills: CLI automation, cloud API, open-source library, remote browser
    # CLI skills require `browser-use` installed (via uv tool install)
    "browser-use@browser-use-skills" = true;

    # REMOVED - redundant or unused:
    # double-check - unnecessary
    # infrastructure-maintainer - too generic
    # monitoring-observability-specialist - splunk repos don't need this
    # awesome-claude-code-plugins - AGGREGATION, use true source (cc-marketplace) instead
  };
}
