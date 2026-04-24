{
  pkgs,
  lib,
  fetchFromGitHub,
}:

# v0.69.3+ requires go >= 1.25.8; use go_1_26 which satisfies that constraint
(pkgs.buildGoModule.override { go = pkgs.go_1_26; }) rec {
  pname = "gh-aw";
  # managed by: nix-update (deps-update-flake.yml)
  version = "0.69.3";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-aw";
    rev = "v${version}"; # Use commit SHA if no tags exist
    hash = "sha256-WqlJvqpr1KhC4V/Sh4GEJDXdS0njL3oPVkzWahXWq94=";
  };

  vendorHash = "sha256-ArVAAdRLQzlC6qN83ujEPEisLvR7TAx3l+gHpBzC2Aw=";

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
