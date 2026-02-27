# nix-ai Root Home-Manager Module
#
# Aggregates all AI CLI configuration into a single home-manager module.
# Consumed by nix-darwin (or any home-manager setup) via:
#   nix-ai.homeManagerModules.default
#
# Module arguments injected via _module.args from flake.nix:
#   ai-assistant-instructions, marketplaceInputs, claude-cookbooks, claude-code-plugins

{
  config,
  pkgs,
  lib,
  ai-assistant-instructions,
  marketplaceInputs,
  claude-cookbooks,
  claude-code-plugins,
  userConfig ? {
    ai.claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
  },
  ...
}:

let
  # Claude Code configuration values
  claudeConfig = import ./claude-config.nix {
    inherit
      config
      pkgs
      lib
      ai-assistant-instructions
      marketplaceInputs
      claude-cookbooks
      ;
  };

  # AgentsMD symlinks from ai-assistant-instructions flake input
  agentsMdSymlinks = {
    "CLAUDE.md" = {
      source = "${ai-assistant-instructions}/CLAUDE.md";
      force = true;
    };
    "GEMINI.md" = {
      source = "${ai-assistant-instructions}/GEMINI.md";
      force = true;
    };
    "AGENTS.md" = {
      source = "${ai-assistant-instructions}/AGENTS.md";
      force = true;
    };
    "agentsmd" = {
      source = "${ai-assistant-instructions}/agentsmd";
      force = true;
    };
  };

  # Gemini CLI configuration
  geminiFiles = import ./gemini.nix {
    inherit
      config
      lib
      pkgs
      ai-assistant-instructions
      ;
  };

  # Codex CLI configuration
  codexFiles = import ./codex.nix { inherit pkgs; };

  # Gemini custom commands
  geminiCommands = import ./gemini-commands.nix {
    inherit lib ai-assistant-instructions;
  };

  # Copilot CLI configuration
  copilotFiles = import ./copilot.nix {
    inherit
      config
      lib
      pkgs
      ai-assistant-instructions
      ;
  };

  # GitHub CLI extensions
  ghExtensions = import ./gh-extensions {
    inherit pkgs lib;
    inherit (pkgs) fetchFromGitHub;
  };
in
{
  imports = [
    ./claude
    ./maestro
    ./ollama.nix
  ];

  config = {
    home = {
      # AI development tools (MCP servers, linters, CLI wrappers)
      inherit (import ./ai-tools.nix { inherit pkgs; }) packages;

      file = geminiFiles.file // codexFiles // geminiCommands // copilotFiles // agentsMdSymlinks;

      activation = geminiFiles.activation // {
        # Claude Code Settings Validation (post-rebuild)
        validateClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${./scripts/validate-claude-settings.sh} \
            "${config.home.homeDirectory}/.claude/settings.json" \
            "${userConfig.ai.claudeSchemaUrl}"
        '';

        # open-webui: installed via uv
        installOpenWebui = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if ! ${lib.getExe pkgs.uv} tool list 2>/dev/null | grep -q "^open-webui"; then
            echo "-> Installing open-webui via uv (Python 3.12)..."
            $DRY_RUN_CMD ${lib.getExe pkgs.uv} tool install open-webui --python 3.12
          fi
        '';
      };
    };

    # Programs configuration
    programs = {
      # Claude Code declarative configuration
      claude = claudeConfig;

      # Claude Code powerline statusline
      claudeStatusline.enable = true;

      # GitHub CLI extension for AI workflows
      gh.extensions = [ ghExtensions.gh-aw ];
    };
  };
}
