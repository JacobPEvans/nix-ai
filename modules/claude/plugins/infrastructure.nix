# Infrastructure & DevOps Plugins
#
# CRITICAL: Marketplace Names
# ============================================================================
# Plugins from multiple marketplaces - marketplace names match manifest values:
#
# 1. wshobson/agents → "@claude-code-workflows"
#    Example: "cloud-infrastructure@claude-code-workflows"
#    NOT "@agents" ✗
#
# 2. basher83/lunar-claude → "@lunar-claude"
# 3. jeremylongshore/claude-code-plugins-plus → "@claude-code-plugins-plus"
#
# See docs/TESTING-MARKETPLACES.md for verification
# ============================================================================
#
# Focused on: Terraform, Proxmox, Nix, Ansible

_:

{
  enabledPlugins = {
    # Proxmox (terraform-proxmox repo)
    "proxmox-infrastructure@lunar-claude" = true;

    # Ansible (user requested restore)
    "ansible-workflows@lunar-claude" = true;

    # Terraform (tf-splunk-aws, terraform-aws-static-website repos)
    "infrastructure-as-code-generator@claude-code-plugins-plus" = true;
    "terraform-module-builder@claude-code-plugins-plus" = true;

    # CI/CD (GitHub Actions in repos)
    "cicd-automation@claude-code-workflows" = true;

    # REMOVED - not actively used:
    # observability-monitoring - moved to development.nix (avoid duplication)
    # cloud-infrastructure - too generic
    # kubernetes-operations - no k8s repos
    # deployment-strategies - too generic
    # deployment-validation - too generic
    # database-design - no database repos
    # application-performance - too generic
  };
}
