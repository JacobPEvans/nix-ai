{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  version = "0.57.2"; # Update from https://github.com/github/gh-aw/releases

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-wG/qxZ64LN3yUytRx7fxmCHD65bB5MCaifMPs/tpWOY=";
  };

  vendorHash = "sha256-XY/xXSPULshrYOFptNSaN7YTQSzq7nJVkvUk4wWu4Rs=";

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
