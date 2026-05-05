#!/usr/bin/env bash
#
# Pre-warm install of cecli-dev via uv tool install.
#
# Called by home-manager activation. Idempotent: only re-installs when
# the live version doesn't match the version pinned in vars/ai-stack.nix
# (passed in via $1).
#
# uv is looked up on PATH rather than via a Nix store reference because
# referencing pkgs.uv from this module pulls a separate uv into the
# home-manager-path closure, which collides with nix-home's python314
# overlay in the buildEnv merge step.

set -eu

target_version="${1:?usage: install-cecli.sh VERSION}"

uv_bin="$(command -v uv 2>/dev/null || true)"
if [ -z "$uv_bin" ]; then
  echo "WARNING: uv not on PATH — skipping cecli pre-warm." >&2
  echo "         Add uv to home.packages or run:" >&2
  echo "         uv tool install --native-tls --python python3.12 cecli-dev==$target_version" >&2
  exit 0
fi

installed_version="$("$uv_bin" tool list \
  | awk '$1 == "cecli-dev" { sub(/^v/, "", $2); print $2; exit }')"

if [ "$installed_version" = "$target_version" ]; then
  exit 0
fi

echo "-> Installing cecli-dev==$target_version via uv..."
"$uv_bin" tool install --upgrade \
  --native-tls --python python3.12 \
  "cecli-dev==$target_version"
