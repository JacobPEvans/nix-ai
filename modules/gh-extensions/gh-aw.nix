{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.buildGoModule rec {
  pname = "gh-aw";
  version = "0.62.5"; # Update from https://github.com/github/gh-aw/releases

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-1M1z2KLlvZAz/tgQqK4EUgwdSxUJHKq85t3NH5H4pg0=";
  };

  vendorHash = "sha256-U2TfzFapK1T7lZ7wO9yIPWw8jiVNSGoDaXXyR2SmkIs=";

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
