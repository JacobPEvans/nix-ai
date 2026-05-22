#!/usr/bin/env bash
set -euo pipefail
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add modules/cecli/package.nix
git diff --cached --quiet && exit 0
git commit -m "fix(deps): update fetchPypi hashes for cecli and mcp"
git push
