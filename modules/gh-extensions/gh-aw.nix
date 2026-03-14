{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  version = "0.58.1"; # Update from https://github.com/github/gh-aw/releases

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-CkX7tWkSOe7YDGgX2wiTZbvjynUqy5p7RYuVvjY01o8=";
  };

  vendorHash = "sha256-y8Zo37K5GIoy2RA08NjzkDGOouC/llte1iGoha+eJzg=";

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
