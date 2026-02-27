# NixOS version tracking
# Used by GitHub Actions workflows for version monitoring
#
# stableVersion: Latest stable NixOS release branch
# Format: "YY.MM" (e.g., "24.05" for May 2024 release, "25.11" for November 2025)
#
# Note: This repo uses nixpkgs-unstable in flake.nix for cutting-edge packages.
# This field tracks the latest stable release for informational purposes only.
#
# Used by:
# - .github/workflows/nixos-release-check.yml - automated update notifications
# - .github/workflows/ci-eol-check.yml - end-of-life validation
{
  stableVersion = "25.11";
}
