#!/usr/bin/env bash
#
# Pre-warm install of @qwen-code/qwen-code via npm. Called by
# home-manager activation when programs.qwen-code.installVia = "npm".
# Idempotent: only re-installs when the live version doesn't match the
# version pinned in vars/ai-stack.nix (passed in via $1).
#
# npm and jq paths are passed in as $2 and $3 so this script does not
# need to hardcode Nix store paths or rely on PATH lookup for them.

set -eu

target_version="${1:?usage: install-qwen-code.sh VERSION NPM_BIN JQ_BIN}"
npm_bin="${2:?missing NPM_BIN}"
jq_bin="${3:?missing JQ_BIN}"

npm_prefix="$HOME/.local/share/npm"

# `npm ls` exits non-zero when there is no package.json yet, which would
# kill home-manager activation under set -e. Default empty and only
# query when the prefix has been initialised.
installed_version=""
if [ -f "$npm_prefix/package.json" ]; then
  installed_version="$("$npm_bin" --prefix "$npm_prefix" ls --depth 0 --json 2>/dev/null \
    | "$jq_bin" -r '.dependencies."@qwen-code/qwen-code".version // ""' \
    || echo "")"
fi

if [ "$installed_version" = "$target_version" ]; then
  exit 0
fi

echo "-> Installing @qwen-code/qwen-code@$target_version via npm..."
mkdir -p "$npm_prefix"
"$npm_bin" install --prefix "$npm_prefix" "@qwen-code/qwen-code@$target_version"
