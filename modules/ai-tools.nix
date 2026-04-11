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
# NIXPKGS PACKAGES (from nixpkgs, available on stable 25.11):
#   github-mcp-server, terraform-mcp-server
#
# HOMEBREW PACKAGES (from modules/darwin/homebrew.nix):
#   codex: OpenAI Codex CLI (moved from nixpkgs to match claude/gemini pattern)
#   block-goose-cli: Block's AI agent (nixpkgs outdated at time of addition)
#   gemini-cli: Google Gemini CLI (moved from nixpkgs due to severe version lag)
#
# BUNX WRAPPER PACKAGES (npm packages not in nixpkgs/homebrew):
#   cclint: @felixgeelhaar/cclint (CLAUDE.md linter)
#   gh-copilot: @githubnext/github-copilot-cli (pinned version)
#   chatgpt: chatgpt-cli (ChatGPT terminal client)
#   claude-flow: claude-flow (multi-agent orchestration)
#   gws: @googleworkspace/cli (pinned version)
#
# UVX WRAPPER PACKAGES (Python packages not in nixpkgs/homebrew):
#   hf: huggingface-hub CLI (model downloads, used with HuggingFace MCP)
#   vllm-mlx: defined in modules/mlx.nix (owns the wrapper + LaunchAgent)
#
# PIPX PACKAGES (Python, installed separately):
#   aider: aider-chat (AI pair programming)
#
# NOTE: These are home-manager packages, not system packages.
# Imported in hosts/macbook-m4/home.nix via home.packages.
#
# ============================================================================
# ADDING NEW NIXPKGS PACKAGES
# ============================================================================
#
# Packages are sourced from stable nixpkgs (25.11). To add a new one:
#   1. Verify availability: nix search nixpkgs <package>
#   2. Add to packages list below
#   3. Add to version check script (scripts/workflows/check-package-versions.sh)

{ pkgs, ... }:

{
  # AI-specific development tools
  # Install via: home.packages = [ ... ] ++ (import ./ai-cli/ai-tools.nix { inherit pkgs; }).packages;
  #
  # See CURRENT STATUS section at the top of this file for package details.
  packages = with pkgs; [
    # ==========================================================================
    # Speech-to-Text / Audio AI
    # ==========================================================================
    # Moved from nix-darwin environment.systemPackages — these are AI tools,
    # not system bootstrapping. sox/portaudio remain in nix-darwin (general C libs).

    whisper-cpp # Local speech-to-text (OpenAI Whisper C++ port, CoreML/Metal)
    openai-whisper # Original OpenAI Whisper (Python, GPU/CPU, broader model support)

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
    # NPM: @githubnext/github-copilot-cli (pinned version)
    (writeShellScriptBin "gh-copilot" ''
      exec ${bun}/bin/bunx --bun @githubnext/github-copilot-cli@0.1.36 "$@"
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
      exec ${bun}/bin/bunx --bun claude-flow@3.5 "$@"
    '')

    # ==========================================================================
    # Google Workspace CLI
    # ==========================================================================
    # Full Workspace API surface with curated Agent Skills (+triage, +watch, etc.)
    # Source: https://github.com/googleworkspace/cli
    # NPM: @googleworkspace/cli (pinned version)
    # Key commands: gws gmail +triage, gws gmail +watch, gws drive +upload
    (writeShellScriptBin "gws" ''
      exec ${bun}/bin/bunx --bun @googleworkspace/cli@0.22.5 "$@"
    '')

    # ==========================================================================
    # Doppler MCP Wrapper
    # ==========================================================================
    # Wraps any MCP server command with Doppler secret injection.
    # Fetches secrets from the ai-ci-automation project at subprocess launch time.
    # Used by mcp/default.nix withDoppler helper — secrets never stored in any file.
    # Usage: doppler-mcp <command> [args...]
    #
    # Logs invocations (command + args) to $XDG_STATE_HOME/doppler-mcp.log.
    # Doppler auth errors go to stderr (handled by `doppler run` natively).
    #
    # IMPORTANT: No synchronous preflight check. A `doppler run -- true` preflight
    # used to run here, but it caused 100% MCP startup failures in Claude Code.
    # When Claude Code launches ~17 servers in parallel, the preflight's Doppler API
    # round-trip (fetching secrets just to run `true`) delayed the MCP server's stdio
    # handshake past Claude Code's connection timeout. The preflight also fetched
    # secrets TWICE — once for the check, once for the real `exec doppler run`.
    # Since `doppler run` already exits non-zero on auth failure with a clear error
    # message, the preflight provided no safety benefit — just latency.
    # Removed 2026-03-25. See modules/mcp/README.md → Troubleshooting.
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
      # Log invocation for audit trail. No preflight — go straight to exec.
      # Auth failures are handled natively by `doppler run` (non-zero exit + stderr).
      # --fallback: cache encrypted secrets locally; use cache if Doppler API is unreachable.
      echo "$(date -u +%FT%TZ) doppler-mcp starting: $(printf '%q ' "$@")" >> "$LOG_FILE"
      FALLBACK="''${XDG_STATE_HOME:-$HOME/.local/state}/doppler-mcp-fallback.enc"
      exec ${pkgs.doppler}/bin/doppler run -p ai-ci-automation -c prd \
        --fallback "$FALLBACK" \
        -- "$@"
    '')

    # sync-mlx-models moved to modules/claude/pal-models.nix
    # (needs MLX config access for dynamic model discovery)

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
      # With DEFAULT_MODEL=auto, PAL works with ANY available provider.
      # Warn about missing keys but only fail if NONE are available.
      provider_secrets=(GEMINI_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY)
      available=0
      for secret in "''${provider_secrets[@]}"; do
        if ${pkgs.doppler}/bin/doppler secrets get "$secret" \
             --project ai-ci-automation \
             --config prd \
             --plain >/dev/null 2>&1; then
          echo "   OK: $secret available"
          available=$((available + 1))
        else
          echo "   WARN: $secret missing (PAL auto mode will use other providers)"
        fi
      done
      if [ "$available" -eq 0 ]; then
        echo "   ERROR: No provider API keys found. PAL MCP will not work."
        exit 1
      fi
      echo "   $available/''${#provider_secrets[@]} providers available"

      echo ""
      echo "4. Last doppler-mcp log entries (if any):"
      # Note: log file has chmod 600 - contents are diagnostic only, no secret values
      if [ -f "$LOG_FILE" ]; then
        ${pkgs.coreutils}/bin/tail -20 "$LOG_FILE"
      else
        echo "   No log file found at $LOG_FILE (no failures recorded)"
      fi

      echo ""
      echo "5. Claude Code MCP connection status:"
      if command -v claude &>/dev/null; then
        pal_status=$(claude mcp list 2>/dev/null | grep "^pal:" || true)
        if [ -n "$pal_status" ]; then
          echo "   $pal_status"
        else
          echo "   PAL not found in Claude Code MCP server list"
          echo "   Register: claude mcp add pal -s user -- doppler-mcp pal-mcp-server"
        fi
      else
        echo "   claude CLI not in PATH — skipping"
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
      exec ${uv}/bin/uvx --from "huggingface-hub==1.9.0" hf "$@"
    '')

    # ==========================================================================
    # Aider - AI pair programming in the terminal
    # ==========================================================================
    # Not available in nixpkgs - python package
    # Source: https://github.com/paul-gauthier/aider
    # PyPI: aider-chat
    # Install: uvx aider-chat  (pipx removed from nix-home — use uvx or nix run instead)
    # This creates a marker comment so users know aider is via uvx

  ];
}
