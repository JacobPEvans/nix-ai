{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  # renovate: datasource=github-releases depName=github/gh-aw
  version = "0.65.0";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-FElsGNDXgiq8opydz2atSTO0eJdL4AYjrwyMPet86DQ=";
  };

  vendorHash = "sha256-6dC1CSl7T2a1gg3GKUwqfEh0SnbOf/XubmPJpXTu/Mo=";

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
