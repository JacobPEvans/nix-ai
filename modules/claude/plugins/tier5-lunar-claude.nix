# Marketplace: lunar-claude
# Source: github.com/basher83/lunar-claude
# Stars (verified 2026-05-02): 18
# Priority Tier: 5 (Niche — infrastructure-specific specialty plugins)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are SUPERSEDED by ALL higher tiers.
#
# Useful for the user's Proxmox + Ansible stack. Re-enable in non-infra
# repos only if their per-repo .claude/settings.json doesn't override.

_:

{
  enabledPlugins = {
    "proxmox-infrastructure@lunar-claude" = true;
    "ansible-workflows@lunar-claude" = true;
  };
}
