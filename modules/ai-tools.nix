# AI Development Tools
#
# Linters, formatters, and utilities specifically for AI coding workflows.
# These tools are NOT general-purpose development tools.
#
# ============================================================================
# PACKAGE HIERARCHY (STRICT - NO EXCEPTIONS)
# ============================================================================
#
# ALWAYS follow this order when choosing how to install a package:
#
# 1. **nixpkgs** (ALWAYS FIRST, NO EXCEPTIONS)
#    - Check: nix search nixpkgs <package>
#    - Use if package exists and is reasonably up-to-date
#    - Benefits: Binary cache, security updates, integration
#    - Example: github-mcp-server, terraform-mcp-server
#
# 2. **homebrew** (ONLY if not in nixpkgs)
#    - Fallback for packages missing from nixpkgs
#    - Check: brew search <package>
#    - Add to modules/darwin/homebrew.nix with clear justification
#    - Document WHY homebrew is needed (not in nixpkgs, severely outdated, etc.)
#
# 3. **bunx wrapper** (for npm packages not in nixpkgs or homebrew)
#    - Standard solution for npm/bun packages
#    - Always pin to specific version: package@x.y.z
#    - Downloads on first run, cached locally by bun
#    - Benefits: Simple, minimal code, easy version updates
#    - Pattern: writeShellScriptBin with bunx --bun
#
# 4. **pipx** (for Python packages not in nixpkgs)
#    - Standard solution for Python CLI tools
#    - Installed separately via: pipx install <package>
#    - Benefits: Isolated environments, easy updates
#
# ============================================================================
# CURRENT STATUS
# ============================================================================
#
# NIXPKGS PACKAGES (sourced via unstable overlay in modules/darwin/common.nix):
#   github-mcp-server, terraform-mcp-server
#
# HOMEBREW PACKAGES (from modules/darwin/homebrew.nix):
#   codex: OpenAI Codex CLI (moved from nixpkgs to match claude/gemini pattern)
#   block-goose-cli: Block's AI agent (nixpkgs outdated at time of addition)
#   gemini-cli: Google Gemini CLI (moved from nixpkgs due to severe version lag)
#
# BUNX WRAPPER PACKAGES (npm packages not in nixpkgs/homebrew):
#   cclint: @felixgeelhaar/cclint@0.12.1
#   gh-copilot: @githubnext/github-copilot-cli@latest (unversioned - upstream)
#   chatgpt: chatgpt-cli@3.3.0
#   claude-flow: claude-flow@2.0.0
#
# PIPX PACKAGES (Python, installed separately):
#   aider: aider-chat (AI pair programming)
#
# NOTE: These are home-manager packages, not system packages.
# Imported in hosts/macbook-m4/home.nix via home.packages.
#
# ============================================================================
# UNSTABLE OVERLAY POLICY
# ============================================================================
#
# AI CLI tools are fast-moving and stable nixpkgs lags behind upstream.
# To add a new nixpkgs AI tool:
#   1. Add to packages list below
#   2. Add to unstable overlay in modules/darwin/common.nix
#   3. Add to version check script (scripts/workflows/check-package-versions.sh)

{ pkgs, ... }:

{
  # AI-specific development tools
  # Install via: home.packages = [ ... ] ++ (import ./ai-cli/ai-tools.nix { inherit pkgs; }).packages;
  #
  # See CURRENT STATUS section at the top of this file for package details.
  packages = with pkgs; [
    # ==========================================================================
    # Claude Code Ecosystem
    # ==========================================================================

    # CLAUDE.md linter - validates AI context files
    # Source: https://github.com/felixgeelhaar/cclint
    # NPM: @felixgeelhaar/cclint (pinned version)
    (writeShellScriptBin "cclint" ''
      exec ${bun}/bin/bunx --bun @felixgeelhaar/cclint@0.12.1 "$@"
    '')

    # ==========================================================================
    # MCP Servers (Model Context Protocol)
    # ==========================================================================
    # Used with Claude Code via `claude mcp add --scope user --transport stdio`
    # Configured in ~/.claude.json (user scope)

    # GitHub MCP Server - GitHub API integration
    # Source: https://github.com/github/github-mcp-server
    # Requires: GITHUB_PERSONAL_ACCESS_TOKEN env var
    github-mcp-server

    # Terraform MCP Server - Terraform/OpenTofu integration
    # Source: https://github.com/hashicorp/terraform-mcp-server
    terraform-mcp-server

    # ==========================================================================
    # GitHub Copilot CLI
    # ==========================================================================
    # Source: https://github.com/github/gh-copilot
    # NPM: @githubnext/github-copilot-cli (using @latest - no stable versioning)
    (writeShellScriptBin "gh-copilot" ''
      exec ${bun}/bin/bunx --bun @githubnext/github-copilot-cli@latest "$@"
    '')

    # ==========================================================================
    # OpenAI ChatGPT CLI
    # ==========================================================================
    # Source: https://github.com/manno/chatgpt-cli
    # NPM: chatgpt-cli (pinned version)
    (writeShellScriptBin "chatgpt" ''
      exec ${bun}/bin/bunx --bun chatgpt-cli@3.3.0 "$@"
    '')

    # ==========================================================================
    # Claude Flow - AI Agent Orchestration Platform
    # ==========================================================================
    # Source: https://github.com/ruvnet/claude-flow
    # NPM: claude-flow (pinned version)
    (writeShellScriptBin "claude-flow" ''
      exec ${bun}/bin/bunx --bun claude-flow@2.7.47 "$@"
    '')

    # ==========================================================================
    # Doppler MCP Wrapper
    # ==========================================================================
    # Wraps any MCP server command with Doppler secret injection.
    # Fetches secrets from the ai-ci-automation project at subprocess launch time.
    # Used by mcp/default.nix withDoppler helper — secrets never stored in any file.
    # Usage: doppler-mcp <command> [args...]
    (writeShellScriptBin "doppler-mcp" ''
      set -euo pipefail
      if [ "$#" -lt 1 ]; then
        echo "Usage: doppler-mcp <command> [args...]" >&2
        echo "Wraps a command with: doppler run -p ai-ci-automation -c prd -- <command> [args...]" >&2
        exit 1
      fi
      exec ${pkgs.doppler}/bin/doppler run -p ai-ci-automation -c prd -- "$@"
    '')

    # ==========================================================================
    # Sync PAL Ollama Models
    # ==========================================================================
    # Refreshes ~/.config/pal-mcp/custom_models.json from `ollama list`.
    # Run after `ollama pull <model>` to make new models available in PAL
    # without a full darwin-rebuild switch.
    (writeShellScriptBin "sync-ollama-models" ''
      set -euo pipefail
      mkdir -p "$HOME/.config/pal-mcp"
      ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags \
        | ${pkgs.jq}/bin/jq --from-file ${./mcp/scripts/pal-models.jq} \
        > "$HOME/.config/pal-mcp/custom_models.json"
      echo "PAL custom models updated. Restart Claude Code to pick up changes."
    '')

    # ==========================================================================
    # Aider - AI pair programming in the terminal
    # ==========================================================================
    # Not available in nixpkgs - python package, use pip/pipx
    # Source: https://github.com/paul-gauthier/aider
    # PyPI: aider-chat
    # Note: Using python3.withPackages pipx from common/packages.nix
    # Install: pipx install aider-chat
    # This creates a marker comment so users know aider is via pipx

  ];
}
