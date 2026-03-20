# Gemini CLI Configuration
#
# Returns { file, activation } attrsets for Google Gemini Code Assist CLI.
# Imported by common.nix: file entries go into home.file, activation into home.activation.
#
# IMPORTANT: settings.json is NOT managed as a read-only symlink!
# Gemini CLI writes auth tokens and runtime state to this file.
# Instead, we use an activation script that deep-merges Nix config
# with existing runtime state, preserving auth tokens across rebuilds.
#
# CRITICAL - tools.allowed vs tools.core:
# =========================================
# DO NOT USE tools.core FOR AUTO-APPROVAL!
#
# Per the official Gemini CLI schema:
# - tools.allowed = "Tool names that bypass the confirmation dialog" (AUTO-APPROVE)
# - tools.core = "Allowlist to RESTRICT built-in tools to a specific set" (LIMITS usage!)
#
# Using tools.core LIMITS what tools Gemini can use, it does NOT grant permissions.
# Always use tools.allowed for auto-approved commands.
#
# Schema reference: https://github.com/google-gemini/gemini-cli/blob/main/schemas/settings.schema.json
#
# Configuration format:
# - allowedTools: List of auto-approved tools (bypass confirmation dialog)
# - excludeTools: List of permanently blocked commands
#
# Permission files:
# - gemini-permissions-allow.nix - allowedTools (auto-approved commands)
# - gemini-permissions-deny.nix - excludeTools (blocked commands)
# - gemini-permissions-ask.nix - Reference only (Gemini doesn't support ask mode)

{
  config,
  lib,
  pkgs,
  ai-assistant-instructions,
  ...
}:

let
  geminiAllow = import ./permissions/gemini-permissions-allow.nix {
    inherit config lib ai-assistant-instructions;
  };
  geminiDeny = import ./permissions/gemini-permissions-deny.nix {
    inherit config lib ai-assistant-instructions;
  };

  # Gemini settings object
  settings = {
    # JSON Schema reference for IDE IntelliSense and validation
    # Official schema from google-gemini/gemini-cli repo
    # NOTE: Gemini CLI has a bug where $schema triggers "not allowed" warning
    # See: https://github.com/google-gemini/gemini-cli/issues/12695
    "$schema" =
      "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json";

    # General settings
    general = {
      # Enable preview features (experimental models, features)
      previewFeatures = true;

      # Disable auto-update (managed via Nix)
      disableAutoUpdate = true;
    };

    # Context file configuration
    # Recognize AGENTS.md as the primary, cross-tool instruction file while also
    # supporting GEMINI.md for compatibility with existing Gemini CLI projects
    # and the official Gemini documentation/examples.
    # AGENTS.md is the unified instruction file used by Claude, Copilot, and Gemini;
    # GEMINI.md is the Gemini-specific alternative that some projects may still use.
    # See: https://geminicli.com/docs/cli/gemini-md/
    context = {
      fileName = [
        "AGENTS.md"
        "GEMINI.md"
      ];
    };

    # Security settings
    # See: https://geminicli.com/docs/cli/trusted-folders/
    security = {
      folderTrust = {
        # Enable folder trust system
        enabled = true;

        # Trusted directories where Gemini can operate without confirmation
        # SECURITY NOTE: Trusting a folder allows Gemini to read/write files
        # and execute commands within that directory without prompts.
        #
        # Trusted:
        # - ~/.config/nix: Nix configuration (this repo)
        # - ~/git: All git repositories (development work)
        #
        # NOT trusted (intentionally):
        # - ~/ (full home): Too broad, includes secrets (.ssh, .gnupg, etc.)
        # - ~/.config: Contains sensitive app configs
        # - /tmp: Potential for symlink attacks
        trustedFolders = [
          "${config.home.homeDirectory}/.config/nix"
          "${config.home.homeDirectory}/git"
        ];
      };
    };

    # Tools configuration (must be nested under "tools" key)
    # See: https://google-gemini.github.io/gemini-cli/docs/get-started/configuration.html
    #
    # CRITICAL: Use "allowed" NOT "core" for auto-approval!
    # - "allowed" = bypass confirmation dialog (what we want)
    # - "core" = RESTRICT available tools (NOT what we want!)
    tools = {
      # Auto-approved tools (bypass confirmation dialog)
      allowed = geminiAllow.allowedTools;

      # Blocked tools (catastrophic operations)
      exclude = geminiDeny.excludeTools;

      # Sandbox configuration (macOS Seatbelt)
      # Uses permissive-open profile: restricts writes outside project directory
      # CRITICAL: Gemini won't execute commands without sandbox enabled
      # See: https://geminicli.com/docs/cli/sandbox/
      sandbox = true;
    };
  };

  # Generate pretty-printed JSON using a derivation with jq
  # This improves readability for debugging and matches Claude's format
  settingsJson =
    pkgs.runCommand "gemini-settings.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        json = builtins.toJSON settings;
        passAsFile = [ "json" ];
      }
      ''
        jq '.' "$jsonPath" > $out
      '';

  homeDir = config.home.homeDirectory;
in
{
  # No home.file entries for settings.json - it must be writable at runtime
  file = { };

  # Activation script: deep-merges Nix config with existing runtime state
  activation = {
    mergeGeminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${pkgs.jq}/bin:$PATH"
      $DRY_RUN_CMD ${./scripts/merge-json-settings.sh} \
        "${settingsJson}" \
        "${homeDir}/.gemini/settings.json"
    '';
  };
}
