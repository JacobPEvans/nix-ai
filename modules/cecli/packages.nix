#
# cecli Module — Package Install
#
# uvx-only today (cecli is not in nixpkgs or Homebrew). Pre-warmed via
# home-manager activation so the binary is on PATH immediately after a
# rebuild — no first-invocation lag, and `which cecli` returns a
# deterministic nix-managed wrapper path rather than ~/.local/bin/cecli.
#
# Mitigations for known uvx weaknesses are tracked in
# docs/architecture/per-agent-flakes.md.
#
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.cecli;
  registry = import ../../vars/ai-stack.nix;
  cecliVersion = registry.cliVersions.cecli;

  # Wrapper that delegates to the uvx-installed binary. Gives us a
  # deterministic Nix-managed PATH entry; uvx still owns the actual
  # interpreter + venv under ~/.local/share/uv/.
  cecliWrapper = pkgs.writeShellScriptBin "cecli" ''
    if [ ! -x "$HOME/.local/bin/cecli" ]; then
      echo "cecli: ~/.local/bin/cecli is missing." >&2
      echo "Re-run darwin-rebuild switch — the activation hook installs it." >&2
      exit 127
    fi
    exec "$HOME/.local/bin/cecli" "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.installVia == "uvx";
        message = ''
          programs.cecli.installVia = "${cfg.installVia}" but only "uvx" is
          implemented today. cecli is not packaged in nixpkgs or Homebrew.
          Set installVia = "uvx" or wait for upstream packaging.
        '';
      }
    ];

    home.packages = [
      cecliWrapper
    ];

    # Pre-warm install via uv (script extracted per no-scripts-in-nix rule).
    # The script looks up `uv` on PATH instead of resolving via a Nix store
    # reference because pulling pkgs.uv into this module's closure ends up
    # propagating a python3.13-env into home-manager-path, which collides
    # with nix-home's python314 overlay at the buildEnv merge step. uv is
    # already in home.packages from modules/ai-tools.nix, so the runtime
    # PATH lookup is reliable.
    home.activation.installCecli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${./scripts/install-cecli.sh} "${cecliVersion}"
    '';
  };
}
