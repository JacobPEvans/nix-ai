{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  # renovate: datasource=github-releases depName=github/gh-aw
  version = "0.65.4";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-uS4A1wey9ZIsuas0hDOpSsHDxSUXKzh/3zqCXyc2Y2w=";
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
