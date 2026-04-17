{
  pkgs,
  lib,
  fetchFromGitHub,
}:

# v0.68.7+ requires go >= 1.25.8; use go_1_26 which satisfies that constraint
(pkgs.buildGoModule.override { go = pkgs.go_1_26; }) rec {
  pname = "gh-aw";
  # managed by: nix-update (deps-update-flake.yml)
  version = "0.68.7";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-CFpt2WKdV93nCdpg8hmTYv9TW/zUOmMVK5HLPp83UyM=";
  };

  vendorHash = "sha256-ArXk+JZoNo9Lm3DFpTqjvQJ1zUj9e4LPXzO0u4jFeQs=";

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
