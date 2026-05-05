#
# Qwen Code Module — Package Install
#
# brew is the preferred install per the install-order rule on darwin
# (nixpkgs first → brew → uvx/npm). brew lives in nix-darwin, not
# home-manager, so this module's contribution is:
#
#   1. A soft assertion that the binary is on PATH when installVia="brew"
#      on darwin (catches the "you forgot to add the formula in
#      nix-darwin" case). On Linux + brew, an eval-time assertion fires
#      directly — brew is darwin-only here.
#   2. An npm pre-warm activation when installVia="npm" (fallback path
#      for hosts without Homebrew, or when the user opts out of brew).
#
# The flake-output `lib.brewFormulae` is what nix-darwin reads to know
# which formulae this module needs — see flake.nix.
#
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.qwen-code;
  registry = import ../../vars/ai-stack.nix;
  qwenVersion = registry.cliVersions.qwen-code;

  # Wrapper for the npm fallback path — keeps PATH lookup deterministic.
  npmWrapper = pkgs.writeShellScriptBin "qwen" ''
    if [ ! -x "$HOME/.local/share/npm/bin/qwen" ]; then
      echo "qwen-code: ~/.local/share/npm/bin/qwen is missing." >&2
      echo "Re-run darwin-rebuild switch — the activation hook installs it." >&2
      exit 127
    fi
    exec "$HOME/.local/share/npm/bin/qwen" "$@"
  '';
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.installVia != "nixpkgs";
            message = ''
              programs.qwen-code.installVia = "nixpkgs" but no nixpkgs
              derivation exists. Pick "brew" (preferred on darwin) or
              "npm" (fallback) until upstream packaging arrives.
            '';
          }
        ];
      }

      (lib.mkIf (cfg.installVia == "brew" && pkgs.stdenv.isDarwin) {
        # nix-darwin actually installs the formula via homebrew.brews,
        # consuming the lib.brewFormulae flake output. The activation
        # check fires AT activation time (warning, not eval-time
        # failure) so users who haven't yet run the companion
        # nix-darwin rebuild get a clear pointer instead of a
        # `command not found`. Gated by isDarwin so non-darwin systems
        # with the default config don't see an irrelevant
        # nix-darwin/homebrew warning — they hit the assertion below
        # instead.
        home.activation.checkQwenInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./scripts/check-qwen-installed.sh}
        '';
      })

      (lib.mkIf (cfg.installVia == "npm") {
        home.packages = [
          npmWrapper
        ];

        # npm and jq paths are baked in as Nix store references so the
        # script doesn't need to hunt for them on PATH (and so the
        # closure tracks them as real dependencies).
        home.activation.installQwenCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./scripts/install-qwen-code.sh} \
            "${qwenVersion}" "${pkgs.nodejs}/bin/npm" "${pkgs.jq}/bin/jq"
        '';
      })
    ]
  );
}
