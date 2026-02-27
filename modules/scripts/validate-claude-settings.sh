#!/usr/bin/env bash
# Validate Claude Code settings.json against JSON Schema
# Called by home-manager activation hook after writeBoundary
#
# Arguments:
#   $1 - Path to settings.json file
#   $2 - Schema URL
#
# Exit codes:
#   0 - Always. Validation failures are only reported as warnings to stderr
#       and do not block activation.
#   1 - Only on argument/usage error.

set -euo pipefail

SETTINGS="${1:-}"
SCHEMA_URL="${2:-}"

if [ -z "$SETTINGS" ] || [ -z "$SCHEMA_URL" ]; then
  echo "Usage: $0 <settings-path> <schema-url>" >&2
  exit 1
fi

if [ ! -f "$SETTINGS" ]; then
  # Settings file doesn't exist yet - normal during first activation
  exit 0
fi

# Run validation using ephemeral nix shell - warn but don't fail activation
nix shell nixpkgs#check-jsonschema -c check-jsonschema --schemafile "$SCHEMA_URL" "$SETTINGS" || {
  echo "Warning: Claude Code settings.json validation failed" >&2
}
