#!/usr/bin/env bash
# Deep-merge a Nix-generated JSON overlay into ~/.claude.json.
# Sourced from settings.nix activation with OVERLAY_FILE and TRUSTED_PROJECT_DIRS set.
# Requires: OVERLAY_FILE, TRUSTED_PROJECT_DIRS (JSON array of dirs), DRY_RUN_CMD, jq on PATH.
#
# Merge strategy:
# - Top-level keys from overlay replace existing values (mcpServers, remoteControlAtStartup)
# - .projects entries are deep-merged: overlay values merge INTO existing project entries
#   (preserving runtime-managed keys like allowedTools, mcpServers per-project, etc.)
# - Trust entries are generated at activation time by scanning TRUSTED_PROJECT_DIRS,
#   since filesystem discovery cannot happen at Nix evaluation time in pure flake mode.

CLAUDE_JSON="$HOME/.claude.json"

# Build project trust entries by scanning each trusted base dir for repo subdirs.
# Each "$baseDir/$repo/main" path gets hasClaudeMdExternalIncludesApproved = true.
_build_trust_overlay() {
  local dirs_json="$1"
  local trust_entry='{"hasClaudeMdExternalIncludesApproved":true,"hasClaudeMdExternalIncludesWarningShown":true,"hasTrustDialogAccepted":true}'
  local projects='{}'

  while IFS= read -r base_dir; do
    base_dir="${base_dir/#\~/$HOME}"
    if [ -d "$base_dir" ]; then
      while IFS= read -r repo_dir; do
        [ -d "$repo_dir" ] || continue
        repo_name=$(basename "$repo_dir")
        # Skip hidden dirs and non-repo-looking entries
        [[ "$repo_name" == .* ]] && continue
        path="${repo_dir}/main"
        [ -d "$path" ] || continue
        projects=$(jq -n --argjson p "$projects" --arg k "$path" --argjson v "$trust_entry" '$p + {($k): $v}')
      done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi
  done < <(jq -r '.[]' <<<"$dirs_json" 2>/dev/null)

  echo "$projects"
}

trust_projects=$(_build_trust_overlay "$TRUSTED_PROJECT_DIRS")

if [ -f "$CLAUDE_JSON" ]; then
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if jq -s \
    --argjson trust "$trust_projects" \
    '
      .[0] as $existing | .[1] as $overlay |
      # Replace top-level keys from overlay (mcpServers etc.), deep-merge .projects.
      ($existing + ($overlay | del(.projects))) | .projects = (($existing.projects // {}) * ($overlay.projects // {}) * $trust)
    ' "$CLAUDE_JSON" "$OVERLAY_FILE" > "$TMP"; then
    $DRY_RUN_CMD mv "$TMP" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: Failed to update \"$CLAUDE_JSON\"; existing file may contain invalid JSON. Fix or remove it to apply settings." >&2
    rm -f "$TMP"
  fi
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if jq --argjson trust "$trust_projects" '. + {projects: $trust}' "$OVERLAY_FILE" > "$TMP"; then
    $DRY_RUN_CMD mv "$TMP" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: Failed to create \"$CLAUDE_JSON\" from overlay; jq returned an error." >&2
    rm -f "$TMP"
  fi
fi

[ -f "$CLAUDE_JSON" ] && $DRY_RUN_CMD chmod 600 "$CLAUDE_JSON"
