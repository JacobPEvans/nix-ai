# Codex Module Options
#
# Declarative options for OpenAI Codex CLI configuration.
# Follows the same patterns as modules/claude/options.nix.
{ lib, ... }:

let
  componentModule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      source = lib.mkOption { type = lib.types.path; };
    };
  };

  hookType = lib.types.nullOr (lib.types.either lib.types.path lib.types.lines);
in
{
  options.programs.codex = {
    # Skills
    skills = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
        description = "Skills sourced from flake inputs (immutable, from Nix store)";
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Local skill files (name -> path to SKILL.md)";
      };
    };

    # Hooks
    hooks = {
      notification = lib.mkOption {
        type = hookType;
        default = null;
        description = "Codex notification hook (path or inline script)";
      };
    };

    # Feature flags (maps to [features] table in config.toml)
    features = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Codex feature flags (maps to [features] in config.toml)";
    };

    # Trusted project directories
    trustedProjectDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional directories to trust (merged with shared permission dirs)";
    };

    # Approval policy
    approvalPolicy = lib.mkOption {
      type = lib.types.enum [
        "untrusted"
        "on-failure"
        "on-request"
        "never"
      ];
      default = "on-request";
      description = "Default approval policy for Codex sessions";
    };

    # MCP servers to exclude from shared definitions
    excludedMcpServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cloudflare"
        "cribl"
        "docker"
        "everything"
        "exa"
        "fetch"
        "filesystem"
        "firecrawl"
        "git"
        "github"
        "terraform"
      ];
      description = "MCP servers to exclude from the shared definitions";
    };
  };
}
