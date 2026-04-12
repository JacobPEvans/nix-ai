# Codex CLI Configuration Module
#
# Declarative configuration for OpenAI Codex CLI.
# Generates config.toml with shared MCP servers, permissions, skills,
# and project trust levels.
#
# Features:
# - Shared MCP server definitions (filtered for Codex compatibility)
# - Declarative skills deployment (~/.codex/skills/ + ~/.agents/skills/)
# - Execpolicy rules file from shared permissions
# - config.toml deep-merge activation (preserves runtime state)
{
  config,
  lib,
  ai-assistant-instructions,
  ...
}:

let
  cfg = config.programs.codex;
in
{
  imports = [
    ./options.nix
    ./settings.nix
    ./components.nix
  ];

  config = lib.mkIf cfg.enable {
    programs.codex = {
      # nix-darwin installs Codex via Homebrew for stable TCC paths.
      package = lib.mkDefault null;
      custom-instructions = lib.mkDefault (builtins.readFile "${ai-assistant-instructions}/AGENTS.md");
      # config.toml is managed via home.activation — do NOT set settings here.
    };

    # Ensure directory structure exists
    home.file.".codex/.keep".text = ''
      # Managed by Nix - programs.codex module
    '';
  };
}
