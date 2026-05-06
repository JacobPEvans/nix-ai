#
# Qwen Code Module — Option Declarations
#
{ lib, ... }:

{
  options.programs.qwen-code = {
    enable = lib.mkEnableOption "Qwen Code (Alibaba terminal coding agent)";

    installVia = lib.mkOption {
      type = lib.types.enum [
        "brew"
      ];
      default = "brew";
      description = ''
        Install source. Currently brew-only — declared via nix-darwin's
        homebrew.brews, sourced from this flake's lib.brewFormulae.
        The npm activation-script fallback was removed in favor of
        proper Nix derivations elsewhere; a buildNpmPackage derivation
        for qwen-code's workspace + cross-platform optionalDependencies
        layout is non-trivial and deferred. Linux hosts need brew (or
        Linuxbrew) to use qwen-code through this module.
      '';
    };

    routing = lib.mkOption {
      type = lib.types.enum [
        "llama-swap"
        "bifrost"
      ];
      default = "llama-swap";
      description = ''
        Inference routing target.
        - llama-swap: Direct to http://127.0.0.1:11434/v1 (local MLX, default).
        - bifrost: Through http://localhost:30080/v1 (multi-provider gateway).
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "coding";
      description = ''
        Default capability-class alias to start sessions with. Resolved
        through services.aiStack.models — `coding` maps to the
        Qwen3-Coder backend in the default registry, which is the most
        natural fit for Qwen Code's intended workload.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Free-form attrs deep-merged into ~/.qwen/settings.json. Use to
        add additional model providers (Dashscope, OpenRouter, etc.)
        without forking the module.
      '';
    };
  };
}
