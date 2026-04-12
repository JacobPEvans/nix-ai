#!/usr/bin/env bash
# check-fabric-version-sync.sh
#
# CI guard: assert that the fabric version pin in flake.nix matches the
# version constant in modules/fabric/package.nix AND the version field in
# modules/claude/fabric-curated-patterns.json.
#
# Why this exists:
#   - Renovate's `nix` manager bumps `flake.nix` flake input pins automatically
#   - The version constant in `modules/fabric/package.nix` is plain text that
#     no manager updates
#   - The version in `fabric-curated-patterns.json` is used in marketplace metadata
#   - If any drift, the build still works (fabric-src is the actual source)
#     but the version labels become lies
#
# When to run:
#   - Pre-commit (manual)
#   - Pre-push CI check
#   - After every Renovate PR that touches flake.nix
#
# Exit codes:
#   0 = versions in sync
#   1 = drift detected (with descriptive error)
#   2 = parse error (file not found or pattern not matched)

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
flake_nix="${repo_root}/flake.nix"
package_nix="${repo_root}/modules/fabric/package.nix"
curated_json="${repo_root}/modules/claude/fabric-curated-patterns.json"

if [ ! -f "$flake_nix" ]; then
  echo "ERROR: flake.nix not found at $flake_nix" >&2
  exit 2
fi

if [ ! -f "$package_nix" ]; then
  echo "ERROR: modules/fabric/package.nix not found at $package_nix" >&2
  exit 2
fi

if [ ! -f "$curated_json" ]; then
  echo "ERROR: fabric-curated-patterns.json not found at $curated_json" >&2
  exit 2
fi

# Extract fabric-src URL pin: github:danielmiessler/fabric/v1.4.444
# Looks for the line `url = "github:danielmiessler/fabric/v...";` inside the
# fabric-src input block.
flake_version=$(
  awk '/fabric-src = \{/,/\};/' "$flake_nix" \
    | grep -oE 'github:danielmiessler/fabric/v[0-9][^"]*' \
    | sed 's|github:danielmiessler/fabric/v||' \
    || true
)

if [ -z "$flake_version" ]; then
  echo "ERROR: could not parse fabric-src version from $flake_nix" >&2
  echo "Expected pattern: github:danielmiessler/fabric/v<VERSION>" >&2
  exit 2
fi

# Extract version constant from package.nix: version = "1.4.444";
package_version=$(
  grep -oE 'version = "[0-9][^"]*"' "$package_nix" \
    | head -1 \
    | sed -E 's/version = "([^"]+)"/\1/' \
    || true
)

if [ -z "$package_version" ]; then
  echo "ERROR: could not parse version constant from $package_nix" >&2
  echo "Expected pattern: version = \"<VERSION>\"" >&2
  exit 2
fi

# Extract version from fabric-curated-patterns.json
json_version=$(
  jq -r '.version' "$curated_json" 2>/dev/null || true
)

if [ -z "$json_version" ]; then
  echo "ERROR: could not parse version from $curated_json" >&2
  echo "Expected top-level \"version\" field" >&2
  exit 2
fi

if [ "$flake_version" != "$package_version" ] || [ "$flake_version" != "$json_version" ]; then
  echo "FAIL: fabric version drift detected" >&2
  echo "  flake.nix fabric-src:                        v${flake_version}" >&2
  echo "  modules/fabric/package.nix version:          ${package_version}" >&2
  echo "  modules/claude/fabric-curated-patterns.json: ${json_version}" >&2
  echo "" >&2
  echo "All three version references must stay in sync. Either Renovate bumped" >&2
  echo "one but not the others, or you edited one manually without updating" >&2
  echo "the rest." >&2
  echo "" >&2
  echo "Fix: edit all three to the same version, then run nix build .#fabric-ai" >&2
  echo "and update the vendorHash in package.nix from the error message." >&2
  exit 1
fi

echo "OK: fabric version in sync across all 3 files (v${flake_version})"
exit 0
