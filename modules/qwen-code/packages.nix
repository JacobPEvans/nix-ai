#
# Qwen Code Module — Package Install
#
# Brew-only install. The formula is declared by nix-darwin's
# homebrew.brews block, sourced from this flake's lib.brewFormulae
# output. This module just contributes a soft activation check that
# warns if the formula isn't installed yet (e.g., the user enabled the
# home-manager module but hasn't run the companion nix-darwin rebuild).
#
# A buildNpmPackage derivation was attempted but qwen-code's workspace
# layout + cross-platform optionalDependencies (six per-OS @lydell/
# node-pty wheels + transitive ENOTCACHED gaps) needs deeper packaging
# work than this PR's scope. Brew works fine on darwin, which is the
# only platform that ships qwen-code today; Linux hosts need brew /
# Linuxbrew to use this module.
#
# The whole module short-circuits on non-darwin (`isDarwin` gate
# below) so enabling it on Linux is a silent no-op rather than an
# eval-time failure — that matches the regression-test harness, which
# evaluates every module with its default config on x86_64-linux.
#
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.qwen-code;
in
{
  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.activation.checkQwenInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./scripts/check-qwen-installed.sh}
    '';
  };
}
