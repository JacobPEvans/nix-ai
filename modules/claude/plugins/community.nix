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
    "obsidian-markdown@obsidian-skills" = true; # Create/edit Obsidian Flavored Markdown
    "obsidian-bases@obsidian-skills" = true; # Work with Obsidian Base files (databases)
    "json-canvas@obsidian-skills" = true; # Handle JSON Canvas file structure
    "obsidian-cli@obsidian-skills" = true; # Vault interactions and plugin/theme dev
    "defuddle@obsidian-skills" = true; # Extract clean markdown from web pages

    # Obsidian Visual Skills - Diagrams (axtonliu/axton-obsidian-visual-skills)
    "excalidraw-diagram-generator@obsidian-visual-skills" = true; # Hand-drawn style diagrams
    "mermaid-visualizer@obsidian-visual-skills" = true; # Professional diagrams
    "obsidian-canvas-creator@obsidian-visual-skills" = true; # Interactive Canvas files

    # REMOVED - redundant or unused:
    # double-check - unnecessary
    # infrastructure-maintainer - too generic
    # monitoring-observability-specialist - splunk repos don't need this
    # awesome-claude-code-plugins - AGGREGATION, use true source (cc-marketplace) instead
  };
}
