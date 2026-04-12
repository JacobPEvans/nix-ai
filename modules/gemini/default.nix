# Gemini CLI Configuration Module
#
# Declarative configuration for Google Gemini CLI.
# Generates settings.json with shared MCP servers, permissions, skills,
# commands, extensions, and folder trust.
#
# CRITICAL - tools.allowed vs tools.core:
# Per the official Gemini CLI schema:
# - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
# - tools.core = "Allowlist to RESTRICT built-in tools to a specific set" (LIMITS usage!)
# Always use tools.allowed for auto-approval, NEVER tools.core!
#
# Features:
# - Shared MCP server definitions (normalized for Gemini format)
# - Declarative skills deployment (~/.gemini/skills/ + ~/.agents/skills/)
# - Auto-generated custom commands from agentsmd
# - Extension management (~/.gemini/extensions/)
# - settings.json deep-merge activation (preserves auth tokens)
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.gemini;
in
{
  imports = [
    ./options.nix
    ./settings.nix
    ./components.nix
    ./extensions.nix
  ];

  config = lib.mkIf cfg.enable {
    # Ensure directory structure exists
    home.file.".gemini/.keep".text = ''
      # Managed by Nix - programs.gemini module
    '';
  };
}
