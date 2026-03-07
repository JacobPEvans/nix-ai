# Unified Claude Code Configuration Module
#
# This module consolidates all Claude Code configuration into a single
# declarative interface: plugins, commands, agents, skills, hooks, MCP servers.
#
# Features:
# - Declarative plugin management via flake inputs
# - Hybrid mode: Nix-managed baseline + runtime /plugin install
# - Cross-platform: Works on Darwin, NixOS, standalone home-manager
# - Generates settings.json (known_marketplaces.json managed by Claude Code at runtime)
#
# Usage:
#   programs.claude = {
#     enable = true;
#     plugins.enabled = { "commit-commands@anthropics/claude-code" = true; };
#   };
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
in
{
  imports = [
    ./options.nix
    ./registry.nix
    ./plugins.nix
    ./components.nix
    ./settings.nix
    ./statusline
    # Note: MCP server configuration is handled in settings.nix via the `mcpServers` option.
    ./auto-claude.nix
    ./auto-claude-reporting.nix
    ./menubar.nix
    ./orphan-cleanup.nix
    ./pal-models.nix
  ];

  config = lib.mkIf cfg.enable {
    # Note: apiKeyHelper now reads config from ~/.config/bws/.env
    # The Python helper (bws_helper.py) will give clear errors if config is missing

    # Ensure ~/.claude directory structure exists
    # Individual sub-modules populate these directories
    home.file = {
      ".claude/.keep".text = ''
        # Managed by Nix - programs.claude module
      '';
      ".claude/plugins/.keep".text = ''
        # Plugin registry managed by Nix
      '';
    }
    // lib.optionalAttrs cfg.apiKeyHelper.enable {
      # API Key Helper script for headless authentication
      # Configuration now comes from ~/.config/bws/.env (not Nix options)
      "${cfg.apiKeyHelper.scriptPath}" = {
        source = ./get-api-key.py; # Python script using bws_helper
        executable = true;
      };
    };

    # Activation scripts for directory and config setup
    # NOTE: "local" marketplace setup removed - Claude Code doesn't use it by default.
    # See docs/CLAUDE-MARKETPLACE-ARCHITECTURE.md for details.
    home.activation = {
      # WakaTime config - fetches API key from Doppler at activation time.
      # Always overwrites on rebuild. Graceful fallback if Doppler is unreachable.
      # umask 077 subshell: file created with 600 perms atomically (no race window).
      wakatimeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -n "$DRY_RUN_CMD" ]; then
          echo "wakatime: dry-run — skipping Doppler fetch" >&2
        else
          WAKA_KEY=$(${pkgs.doppler}/bin/doppler secrets get WAKATIME_API_KEY \
            -p ai-ci-automation -c prd --plain 2>/dev/null) || true
          if [ -n "$WAKA_KEY" ]; then
            (
              umask 077
              printf '[settings]\napi_key = %s\n' "$WAKA_KEY" \
                > "${config.home.homeDirectory}/.wakatime.cfg"
            )
          elif [ -f "${config.home.homeDirectory}/.wakatime.cfg" ]; then
            echo "wakatime: Doppler unreachable — keeping existing config" >&2
          else
            echo "wakatime: Doppler unreachable — no config created" >&2
          fi
        fi
      '';
    };
  };
}
