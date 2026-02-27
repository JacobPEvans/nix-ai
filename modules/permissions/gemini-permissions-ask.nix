# Gemini CLI User-Prompted Commands (ASK List - REFERENCE ONLY)
#
# IMPORTANT: Gemini CLI does NOT have an "ask" mode. Commands are either allowed
# (tools.allowed) or blocked (tools.exclude). This file exists ONLY for reference
# to keep sync with Claude and Copilot permission structures.
#
# CRITICAL - tools.allowed vs tools.core:
# Per the official Gemini CLI schema:
# - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
# - tools.core = "Allowlist to RESTRICT built-in tools" (LIMITS usage!)
# NEVER use tools.core for auto-approval - it restricts, not grants!
#
# FILE STRUCTURE:
# - gemini-permissions-allow.nix - allowedTools → tools.allowed (auto-approved)
# - gemini-permissions-ask.nix (this file) - Commands that would require confirmation (reference only)
# - gemini-permissions-deny.nix - excludeTools → tools.exclude (permanently blocked)
#
# NOTE: These permission lists are kept in sync across Claude, Gemini, and Copilot.
# Currently each AI has separate files. Future improvement: DRY refactor to share
# common command lists across all AI tools.
#
# The commands below are the same ones in Claude's ask list. They are commented
# out because Gemini doesn't use this file - it's purely for documentation and
# to maintain parity across AI tool configurations.
#
# WARNING: Since Gemini CLI doesn't support "ask" mode, users must exercise extra
# caution when using Gemini with these commands. Consider using Claude Code for
# tasks involving these operations if you want confirmation prompts.

_:

{
  # This file is not imported anywhere - it exists for reference only.
  # The commands below match Claude's askList for consistency.

  # === COMMANDS THAT WOULD REQUIRE CONFIRMATION (if Gemini supported it) ===
  #
  # systemScriptCommands = [
  #   "ShellTool(osascript)"
  #   "ShellTool(osascript -e)"
  # ];
  #
  # systemInfoDisclosureCommands = [
  #   "ShellTool(system_profiler)"
  #   "ShellTool(log show)"
  # ];
  #
  # macosConfigCommands = [
  #   "ShellTool(defaults read)"
  # ];
  #
  # gitDestructiveOperations = [
  #   "ShellTool(git reset)"
  # ];
  #
  # securityOperations = [
  #   "ShellTool(gpg)"
  #   "ShellTool(chown)"
  # ];
  #
  # dangerousFileOperations = [
  #   "ShellTool(chmod)"
  #   "ShellTool(rm)"
  #   "ShellTool(rmdir)"
  #   "ShellTool(cp)"
  #   "ShellTool(mv)"
  #   "ShellTool(sed -i)"
  #   "ShellTool(sed --in-place)"
  # ];
  #
  # dockerPrivilegedOperations = [
  #   "ShellTool(docker exec)"
  #   "ShellTool(docker run)"
  # ];
  #
  # kubernetesDestructiveOperations = [
  #   "ShellTool(kubectl apply)"
  #   "ShellTool(kubectl create)"
  #   "ShellTool(kubectl delete)"
  #   "ShellTool(kubectl set)"
  #   "ShellTool(kubectl patch)"
  #   "ShellTool(helm install)"
  #   "ShellTool(helm upgrade)"
  #   "ShellTool(helm uninstall)"
  # ];
  #
  # awsDestructiveOperations = [
  #   "ShellTool(aws s3 cp)"
  #   "ShellTool(aws s3 sync)"
  #   "ShellTool(aws s3 rm)"
  #   "ShellTool(aws ec2 run-instances)"
  #   "ShellTool(aws ec2 terminate-instances)"
  #   "ShellTool(aws lambda invoke)"
  #   "ShellTool(aws cloudformation delete-stack)"
  # ];
  #
  # packageExecutionCommands = [
  #   "ShellTool(npx)"
  # ];
  #
  # databaseModificationCommands = [
  #   "ShellTool(sqlite3)"
  #   "ShellTool(mongosh)"
  # ];
}
