#
# Qwen Code Module — Package Install
#
# brew is the preferred install per the install-order rule on darwin
# (nixpkgs first → brew → uvx/npm). brew lives in nix-darwin, not
# home-manager, so this module's contribution is:
#
#   1. A soft assertion that the binary is on PATH when installVia="brew"
#      (catches the "you forgot to add the formula in nix-darwin" case).
#   2. An npm pre-warm activation when installVia="npm" (fallback path
#      for hosts without Homebrew).
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

      (lib.mkIf (cfg.installVia == "brew") {
        # nix-darwin actually installs the formula via homebrew.brews,
        # consuming the lib.brewFormulae flake output. The check below
        # fires AT activation time (warning, not eval-time failure) so
        # users who haven't yet run the companion nix-darwin rebuild get
        # a clear pointer instead of a `command not found`.
        home.activation.checkQwenInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if ! command -v qwen >/dev/null 2>&1; then
            echo "WARNING: programs.qwen-code is enabled but \`qwen\` is not on PATH." >&2
            echo "  Add \"qwen-code\" to homebrew.brews in nix-darwin and rebuild." >&2
            echo "  Or set programs.qwen-code.installVia = \"npm\" for a Nix-managed install." >&2
          fi
        '';
      })

      (lib.mkIf (cfg.installVia == "npm") {
        # nodejs is referenced via ${pkgs.nodejs}/bin/npm in the activation
        # hook below, which keeps it in the closure without putting another
        # node interpreter on PATH.
        home.packages = [
          npmWrapper
        ];

        home.activation.installQwenCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          target_version="${qwenVersion}"
          npm_prefix="$HOME/.local/share/npm"
          installed_version="$(${pkgs.nodejs}/bin/npm --prefix "$npm_prefix" ls --depth 0 --json 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r '.dependencies."@qwen-code/qwen-code".version // ""')"
          if [ "$installed_version" != "$target_version" ]; then
            echo "-> Installing @qwen-code/qwen-code@$target_version via npm..."
            $DRY_RUN_CMD mkdir -p "$npm_prefix"
            $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install --prefix "$npm_prefix" \
              "@qwen-code/qwen-code@$target_version"
          fi
        '';
      })
    ]
  );
}
