# GitHub CLI Extensions
#
# Declarative management of gh extensions through Home Manager.
# Extensions are linked via XDG data directory and discovered by gh.

{
  pkgs,
  lib,
  fetchFromGitHub,
}:

{
  gh-aw = import ./gh-aw.nix { inherit pkgs lib fetchFromGitHub; };
}
