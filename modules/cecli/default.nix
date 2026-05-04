#
# cecli Module — Aggregator
#
# AI pair programming in the terminal. cecli is an actively maintained
# fork of Aider (https://github.com/cecli-dev/cecli, PyPI: cecli-dev) that
# preserves Aider's UX — including a backward-compat `aider-ce` entry
# point — while shipping bug fixes and new features.
#
# Routes through the local MLX stack (llama-swap at
# http://127.0.0.1:11434/v1) by default so it works with open-source
# models (Qwen3-Coder, Gemma, etc.) without cloud API keys. Cloud access
# is opt-in via the `d-cecli` shell alias (Doppler-injected) or by
# switching programs.cecli.routing to "bifrost".
#
# Why uvx (not nixpkgs / brew):
#   - Not packaged in nixpkgs.
#   - Not packaged in Homebrew.
#   - cecli's transitive deps include sounddevice / soundfile / pydub
#     whose tests get SIGKILLed by the macOS Nix sandbox. Building those
#     in nix is a non-starter on darwin without overlay test-skip
#     workarounds; uvx installs in user-space and avoids the sandbox
#     entirely.
#
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.cecli;
in
{
  imports = [
    ./options.nix
    ./settings.nix
    ./packages.nix
  ];

  config = lib.mkIf cfg.enable {
    home.file.".cecli/.keep".text = "# Managed by Nix — programs.cecli\n";
  };
}
