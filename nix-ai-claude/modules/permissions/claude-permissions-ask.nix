# Claude Code Ask-Mode Commands (ASK List)
#
# Commands that require user confirmation before execution.
# Currently empty - this is intentional.
#
# DESIGN DECISION:
# This repository uses a binary allow/deny permission model:
# - Allow: Auto-approved, safe commands
# - Deny: Permanently blocked, dangerous commands
# - Ask: Not used (empty by design)
#
# The ask list could be populated in the future for commands that need
# case-by-case confirmation, but the current model is sufficient for
# autonomous AI operation while maintaining security.
#
# SINGLE SOURCE OF TRUTH:
# Command definitions would go in ai-cli/common/permissions.nix
# This file only applies Claude-specific formatting.

{
  config,
  lib,
  ...
}:

{
  # Export ask permissions list (currently empty)
  ask = [ ];
}
