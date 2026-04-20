# nix-ai Root Home-Manager Module
#
# Aggregates all AI CLI configuration into a single home-manager module.
# Consumed by nix-darwin (or any home-manager setup) via:
#   nix-ai.homeManagerModules.default
#
# Module arguments injected via _module.args from flake.nix (see homeManagerModules)

{
  config,
  pkgs,
  lib,
  ai-assistant-instructions,
  marketplaceInputs,
  claude-cookbooks,
  claude-code-plugins,
  fabric-src,
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
      fabric-src
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

  # ── Cross-tool skill discovery ──────────────────────────────────────
  # Discovers SKILL.md files from plugin repos and builds a list usable by
  # both Codex and Gemini modules via skills.fromFlakeInputs.
  # Pattern: <plugin>/skills/<skill-name>/SKILL.md

  discoverSkills =
    input:
    let
      topDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir input);
      pluginSkills =
        pluginName:
        let
          skillsPath = "${input}/${pluginName}/skills";
          hasSkills = builtins.pathExists skillsPath;
          skillDirs =
            if hasSkills then
              lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsPath)
            else
              { };
        in
        lib.mapAttrsToList
          (skillName: _: {
            name = skillName;
            source = "${skillsPath}/${skillName}/SKILL.md";
          })
          (
            lib.filterAttrs (skillName: _: builtins.pathExists "${skillsPath}/${skillName}/SKILL.md") skillDirs
          );
    in
    lib.concatMap pluginSkills (builtins.attrNames topDirs);

  # Skills from JacobPEvans/claude-code-plugins (tool-agnostic markdown)
  sharedSkills = discoverSkills marketplaceInputs.jacobpevans-cc-plugins;
in
{
  imports = [
    ./claude
    ./codex
    ./gemini
    ./fabric
    ./maestro
    ./mlx
    ./open-webui.nix
  ];

  config = {
    home = {
      # AI development tools (MCP servers, linters, CLI wrappers)
      inherit (import ./ai-tools.nix { inherit pkgs; }) packages;

      file = copilotFiles // agentsMdSymlinks;

      activation = {
        # Claude Code Settings Validation (post-rebuild)
        validateClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${./scripts/validate-claude-settings.sh} \
            "${config.home.homeDirectory}/.claude/settings.json" \
            "${userConfig.ai.claudeSchemaUrl}"
        '';

        # open-webui: installed via uv (nixpkgs broken on darwin — see modules/open-webui.nix)
        installOpenWebui = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if ! ${lib.getExe pkgs.uv} tool list 2>/dev/null | grep -q "^open-webui"; then
            echo "-> Installing open-webui via uv (Python 3.14)..."
            $DRY_RUN_CMD ${lib.getExe pkgs.uv} tool install "open-webui==0.8.12" --python 3.14
          fi
        '';

        # browser-use: CLI for browser automation (not in nixpkgs)
        installBrowserUse = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if ! ${lib.getExe pkgs.uv} tool list 2>/dev/null | grep -q "^browser-use"; then
            echo "-> Installing browser-use via uv..."
            $DRY_RUN_CMD ${lib.getExe pkgs.uv} tool install "browser-use==0.12.6"
          fi
        '';
      };
    };

    # Programs configuration
    programs = {
      # Claude Code declarative configuration
      claude = claudeConfig;

      # Claude Code statusline (switched from powerline to daniel3303)
      claudeStatusline.enable = false; # Disabled (kept for easy re-enable)
      claudeStatuslineDaniel3303.enable = true; # Active: ClaudeCodeStatusLine (2-line)

      # OpenAI Codex configuration (settings handled by modules/codex/)
      codex = {
        enable = true;
        skills.fromFlakeInputs = sharedSkills;
      };

      # Gemini CLI configuration (settings handled by modules/gemini/)
      gemini = {
        enable = true;
        skills.fromFlakeInputs = sharedSkills;
        worktrees = true;
        sandboxAllowedPaths = [ "${config.home.homeDirectory}/git" ];
      };

      # MLX inference server (vllm-mlx on port 11434)
      mlx.enable = true;

      # Fabric — 252+ AI prompt patterns + CLI (defaults to MLX backend)
      # REST API server is opt-in via programs.fabric.enableServer
      fabric.enable = true;

      # GitHub CLI extension for AI workflows
      gh.extensions = [ ghExtensions.gh-aw ];
    };
  };
}
