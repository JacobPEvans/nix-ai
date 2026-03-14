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
# UVX WRAPPER PACKAGES (Python packages not in nixpkgs/homebrew):
#   hf: huggingface-hub==1.6.0 CLI (model downloads, used with HuggingFace MCP)
#   vllm-mlx: defined in modules/mlx.nix (owns the wrapper + LaunchAgent)
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
    #
    # Logs failures to $XDG_STATE_HOME/doppler-mcp.log for diagnosing MCP startup
    # failures (Doppler auth errors, missing secrets, etc.).
    (writeShellScriptBin "doppler-mcp" ''
      set -euo pipefail
      if [ "$#" -lt 1 ]; then
        echo "Usage: doppler-mcp <command> [args...]" >&2
        echo "Wraps a command with: doppler run -p ai-ci-automation -c prd -- <command> [args...]" >&2
        exit 1
      fi
      LOG_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp.log"
      mkdir -p "$(dirname "$LOG_FILE")"
      touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
      # Preflight: verify Doppler auth before launching the MCP server.
      # Only this check's stderr is logged; the wrapped command's stderr
      # flows to the caller unchanged (important for MCP JSON-RPC communication).
      set +e
      ${pkgs.doppler}/bin/doppler run -p ai-ci-automation -c prd -- true 1>/dev/null 2>>"$LOG_FILE"
      _preflight=$?
      set -e
      if [ "$_preflight" -ne 0 ]; then
        echo "$(date -u +%FT%TZ) doppler-mcp preflight failed. Exit: $_preflight" >> "$LOG_FILE"
        ${pkgs.doppler}/bin/doppler --version >> "$LOG_FILE" 2>&1 || true
        ${pkgs.doppler}/bin/doppler me >> "$LOG_FILE" 2>&1 || true
        exit "$_preflight"
      fi
      # Preflight passed — exec the real command, restoring proper signal forwarding
      # and leaving stderr unredirected for the MCP server.
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
    # Check PAL MCP Health
    # ==========================================================================
    # Verifies that doppler-mcp can authenticate and access PAL secrets.
    # Run after a darwin-rebuild switch to confirm the PAL MCP server will start.
    # Also useful for diagnosing why PAL is absent from Claude Code sessions.
    (writeShellScriptBin "check-pal-mcp" ''
      set -euo pipefail
      LOG_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp.log"

      echo "=== PAL MCP Health Check ==="

      echo ""
      echo "1. Doppler version:"
      ${pkgs.doppler}/bin/doppler --version

      echo ""
      echo "2. Doppler auth status:"
      ${pkgs.doppler}/bin/doppler me 2>&1 || {
        echo "   ERROR: Not authenticated. Run: doppler login"
        exit 1
      }

      echo ""
      echo "3. PAL secrets (ai-ci-automation/prd):"
      required_secrets=(GEMINI_API_KEY OPENROUTER_API_KEY OLLAMA_HOST)
      missing_any=0
      for secret in "''${required_secrets[@]}"; do
        if ${pkgs.doppler}/bin/doppler secrets get "$secret" \
             --project ai-ci-automation \
             --config prd \
             --plain >/dev/null 2>&1; then
          echo "   OK: $secret available"
        else
          echo "   ERROR: $secret missing or unreadable"
          missing_any=1
        fi
      done
      if [ "$missing_any" -ne 0 ]; then
        echo "   One or more required PAL secrets are missing or inaccessible."
        exit 1
      fi

      echo ""
      echo "4. Last doppler-mcp log entries (if any):"
      # Note: log file has chmod 600 - contents are diagnostic only, no secret values
      if [ -f "$LOG_FILE" ]; then
        ${pkgs.coreutils}/bin/tail -20 "$LOG_FILE"
      else
        echo "   No log file found at $LOG_FILE (no failures recorded)"
      fi

      echo ""
      echo "=== Health check complete ==="
    '')

    # ==========================================================================
    # Splunk MCP Connect Wrapper
    # ==========================================================================
    # Wraps the Splunk MCP Server App connection via mcp-remote stdio proxy.
    # Reads SPLUNK_MCP_ENDPOINT and SPLUNK_MCP_TOKEN from env (injected by
    # doppler-mcp from Doppler ai-ci-automation/prd project).
    # MCP server entry: nix-darwin hosts/macbook-m4/home.nix (infrastructure, not AI-specific)
    # Usage: splunk-mcp-connect (no args — called by Claude Code MCP server config)
    (writeShellScriptBin "splunk-mcp-connect" ''
      set -euo pipefail
      : "''${SPLUNK_MCP_ENDPOINT:?SPLUNK_MCP_ENDPOINT not set in Doppler}"
      : "''${SPLUNK_MCP_TOKEN:?SPLUNK_MCP_TOKEN not set in Doppler}"
      # SECURITY NOTE: Bearer token is visible in process list via --header arg.
      # This is a known mcp-remote limitation — no stdin/env-based header injection
      # exists yet. Mitigated by: (1) macOS single-user system, (2) token is
      # Splunk-scoped with limited capabilities, (3) rotatable via Doppler.
      export NODE_TLS_REJECT_UNAUTHORIZED=0  # Self-signed cert on Splunk; scoped to mcp-remote only
      exec ${bun}/bin/bunx --bun mcp-remote@0.1.38 \
        "$SPLUNK_MCP_ENDPOINT" \
        --header "Authorization: Bearer $SPLUNK_MCP_TOKEN"
    '')

    # ==========================================================================
    # HuggingFace Hub CLI
    # ==========================================================================
    # Download and manage models (especially MLX-quantized models).
    # Used alongside the HuggingFace MCP server: search via MCP, download via hf CLI.
    # Source: https://github.com/huggingface/huggingface_hub
    # PyPI: huggingface-hub (provides `hf` entry point)
    # Requires: HF_TOKEN env var (from macOS Keychain via nix-darwin shell init)
    (writeShellScriptBin "hf" ''
      exec ${uv}/bin/uvx --from "huggingface-hub==1.6.0" hf "$@"
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
