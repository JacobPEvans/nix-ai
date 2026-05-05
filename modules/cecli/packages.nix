#
# cecli Module — Package Install
#
# cecli is built from PyPI as a real Nix derivation in
# modules/cecli/package.nix and exposed via the flake's
# `packages.<system>.cecli` output. This module just adds it to the
# user's home.packages — no activation scripts, no uvx shim, no
# `installVia` choice (only one source today).
#
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.cecli;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.cecli
    ];
  };
}
