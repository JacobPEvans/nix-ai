# Official Anthropic Plugins
#
# CRITICAL: Plugin Reference Format
# ============================================================================
# Format: "plugin-name@marketplace-name"
#
# The marketplace-name MUST match the key in marketplaces.nix, which MUST
# match the `name` field from the marketplace's .claude-plugin/marketplace.json
#
# Examples:
#   - "commit-commands@claude-plugins-official" ✓ CORRECT
#   - "example-skills@anthropic-agent-skills" ✓ CORRECT
#   - "example-skills@skills" ✗ WRONG (marketplace is anthropic-agent-skills, not skills)
#   - "backend-dev@agents" ✗ WRONG (marketplace is claude-code-workflows, not agents)
#
# How to verify: See docs/TESTING-MARKETPLACES.md
# ============================================================================
#
# Minimal set for actual usage patterns based on JacobPEvans repos:
# Terraform, Nix, Python, Splunk, Proxmox, Shell scripts

_:

{
  enabledPlugins = {
    # Anthropic Official Plugins - Document Skills (xlsx, docx, pptx, pdf)
    "document-skills@anthropic-agent-skills" = true;

    # Git Workflow (essential)
    "commit-commands@claude-plugins-official" = true;

    # Code Review (essential)
    "code-review@claude-plugins-official" = true;
    "code-simplifier@claude-plugins-official" = true;
    "pr-review-toolkit@claude-plugins-official" = true;

    # Feature Development (useful)
    "feature-dev@claude-plugins-official" = true;

    # Security (useful for infra work)
    "security-guidance@claude-plugins-official" = true;

    # Plugin Development (user maintains claude-code-plugins repo)
    "plugin-dev@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;

    # Setup & Management
    "claude-code-setup@claude-plugins-official" = true;
    "claude-md-management@claude-plugins-official" = true;

    # Language Servers & Developer Tools
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = false; # Minimal TS usage

    # Workflow
    # DISABLED - New Opus 4.6 and Agent Teams sort of handle this
    "ralph-loop@claude-plugins-official" = false;

    # Explicitly disabled - tracked for visibility
    "example-plugin@claude-plugins-official" = false;

    # External plugins (GitHub, Slack, Context7, etc.) moved to external.nix
  };
}
