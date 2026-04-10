#
# Fabric Module — Option Declarations
#
# All `options.programs.fabric` declarations live here.
#
{ config, lib, ... }:
{
  options.programs.fabric = {
    enable = lib.mkEnableOption "Daniel Miessler's Fabric AI prompt pattern framework";

    enableServer = lib.mkEnableOption "Fabric REST API server as a macOS LaunchAgent";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the fabric REST API server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8180;
      description = ''
        Port for the fabric REST API server.

        Default 8180 avoids conflicts with:
        - 8080: Open WebUI
        - 11434: llama-swap proxy (MLX stack)
        - 11436: vllm-mlx backend
        - 27124: Obsidian Local REST API
      '';
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = ''
        Default model fabric should use when no `--model` flag is specified.

        Routes through the local MLX stack at http://127.0.0.1:11434/v1 by default.
        Override to use a cloud provider model (e.g. "claude-3-5-sonnet-20241022",
        "gpt-4o", "gemini-1.5-pro") but be aware fabric needs API keys configured
        in ~/.config/fabric/.env for those backends.
      '';
    };

    patternsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/fabric/patterns";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.config/fabric/patterns"'';
      description = ''
        Path where fabric's 252+ pattern directories are symlinked from the
        fabric-src flake input. Each pattern is a directory containing system.md
        (AI instructions) and user.md (human documentation).
      '';
    };
  };
}
