#!/usr/bin/env bash
# Validate Claude settings JSON structure, types, and values.
# Called from tests/nix/claude-settings-json.nix with jq on PATH.
# Usage: validate-settings-json.sh <json-file-path>
set -euo pipefail

jsonPath="$1"
echo "Validating settings JSON structure..."

# Verify required keys exist
jq -e 'has("$schema")' "$jsonPath" > /dev/null || { echo "FAIL: missing \$schema"; exit 1; }
jq -e 'has("alwaysThinkingEnabled")' "$jsonPath" > /dev/null || { echo "FAIL: missing alwaysThinkingEnabled"; exit 1; }
jq -e 'has("permissions")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions"; exit 1; }
jq -e 'has("extraKnownMarketplaces")' "$jsonPath" > /dev/null || { echo "FAIL: missing extraKnownMarketplaces"; exit 1; }
jq -e 'has("enabledPlugins")' "$jsonPath" > /dev/null || { echo "FAIL: missing enabledPlugins"; exit 1; }
jq -e 'has("statusLine")' "$jsonPath" > /dev/null || { echo "FAIL: missing statusLine"; exit 1; }

# Verify permission structure
jq -e '.permissions | has("allow")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.allow"; exit 1; }
jq -e '.permissions | has("deny")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.deny"; exit 1; }
jq -e '.permissions | has("ask")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.ask"; exit 1; }
jq -e '.permissions | has("additionalDirectories")' "$jsonPath" > /dev/null || { echo "FAIL: missing permissions.additionalDirectories"; exit 1; }

# Verify types
jq -e '.alwaysThinkingEnabled | type == "boolean"' "$jsonPath" > /dev/null || { echo "FAIL: alwaysThinkingEnabled not boolean"; exit 1; }
jq -e '.permissions.allow | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.allow not array"; exit 1; }
jq -e '.permissions.deny | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.deny not array"; exit 1; }
jq -e '.permissions.ask | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: permissions.ask not array"; exit 1; }
jq -e '.permissions.additionalDirectories | type == "array"' "$jsonPath" > /dev/null || { echo "FAIL: additionalDirectories not array"; exit 1; }
jq -e '.statusLine | type == "object"' "$jsonPath" > /dev/null || { echo "FAIL: statusLine not object"; exit 1; }
jq -e '.extraKnownMarketplaces | type == "object"' "$jsonPath" > /dev/null || { echo "FAIL: extraKnownMarketplaces not object"; exit 1; }

# Verify values
jq -e '."$schema" == "https://json.schemastore.org/claude-code-settings.json"' "$jsonPath" > /dev/null || { echo "FAIL: wrong schema URL"; exit 1; }
jq -e '.alwaysThinkingEnabled == true' "$jsonPath" > /dev/null || { echo "FAIL: alwaysThinkingEnabled should be true"; exit 1; }
jq -e '.permissions.allow | length == 2' "$jsonPath" > /dev/null || { echo "FAIL: expected 2 allow entries"; exit 1; }
jq -e '.permissions.deny | length == 1' "$jsonPath" > /dev/null || { echo "FAIL: expected 1 deny entry"; exit 1; }
jq -e '.permissions.ask | length == 0' "$jsonPath" > /dev/null || { echo "FAIL: expected 0 ask entries"; exit 1; }
jq -e '.statusLine.type == "command"' "$jsonPath" > /dev/null || { echo "FAIL: statusLine.type should be command"; exit 1; }

echo "Settings JSON: 6 keys, 5 permission fields, 6 type checks, 6 value checks passed"
