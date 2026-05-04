#
# Qwen Code Module — Aggregator
#
# Qwen Code (https://github.com/QwenLM/qwen-code) is Alibaba's terminal
# coding agent. Claude-Code-style UX for Qwen3-Coder and any other
# OpenAI/Anthropic/Gemini-compatible endpoint.
#
# Routes through the local MLX stack (llama-swap at
# http://127.0.0.1:11434/v1) by default — picks up the Qwen3-Coder
# model that backs the `coding` / `quickest` capability classes. Cloud
# Dashscope / OpenRouter / OpenAI access is opt-in via the `d-qwen`
# Doppler-wrapped shell alias.
#
# Why brew (not nixpkgs / uvx):
#   - Not packaged in nixpkgs.
#   - Homebrew has a bottled formula (`qwen-code`) — this is the
#     install-order rule's preferred path after nixpkgs.
#   - npm fallback (`@qwen-code/qwen-code`) is implemented for
#     non-darwin hosts.
#
# The brew install itself lives in nix-darwin (homebrew.brews is a
# nix-darwin option, not a home-manager one). This module exposes the
# required formula list via the lib.brewFormulae flake output for
# nix-darwin to consume; the module itself only handles config + an
# assertion that the binary is on PATH.
#
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.qwen-code;
in
{
  imports = [
    ./options.nix
    ./settings.nix
    ./packages.nix
  ];

  config = lib.mkIf cfg.enable {
    home.file.".qwen/.keep".text = "# Managed by Nix — programs.qwen-code\n";
  };
}
