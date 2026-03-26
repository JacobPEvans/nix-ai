{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  # renovate: datasource=github-releases depName=github/gh-aw
  version = "0.64.0";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-lQ6jZflEsPxoDELR1ntYEB6238ygl6fvmh99jKV62Vs=";
  };

  vendorHash = "sha256-R0m6RDgnprYB+boh+eDp+5dYhoepwc0qyLvCylS77pU=";

  # Build from cmd/gh-aw directory
  subPackages = [ "cmd/gh-aw" ];

  meta = with lib; {
    description = "GitHub Agentic Workflows CLI extension";
    homepage = "https://github.com/github/gh-aw";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.darwin ++ platforms.linux;
  };
}
