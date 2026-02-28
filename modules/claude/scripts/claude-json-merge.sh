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
  local paths=()

  while IFS= read -r base_dir; do
    base_dir="${base_dir/#\~/$HOME}"
    [ -d "$base_dir" ] || continue
    while IFS= read -r repo_dir; do
      local repo_name
      repo_name=$(basename "$repo_dir")
      # Skip hidden dirs and non-repo-looking entries
      [[ "$repo_name" == .* ]] && continue
      local path="${repo_dir}/main"
      [ -d "$path" ] || continue
      paths+=("$path")
    done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  done < <(jq -r '.[]' <<<"$dirs_json" 2>/dev/null)

  if [ ${#paths[@]} -eq 0 ]; then
    echo '{}'
    return
  fi

  # Build entire trust object in one jq call instead of one per path
  printf '%s\n' "${paths[@]}" | jq -Rs --argjson trust "$trust_entry" '
    split("\n") | map(select(length > 0)) | map({(.): $trust}) | add // {}
  '
}

# Atomically write jq output to CLAUDE_JSON via a temp file.
# Usage: _jq_to_file <warning-msg> [jq args...]
_jq_to_file() {
  local msg="$1"; shift
  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  if jq "$@" > "$tmp"; then
    $DRY_RUN_CMD mv "$tmp" "$CLAUDE_JSON"
    trap - EXIT
  else
    echo "warning: $msg" >&2
    rm -f "$tmp"
  fi
}

trust_projects=$(_build_trust_overlay "$TRUSTED_PROJECT_DIRS")

if [ -f "$CLAUDE_JSON" ]; then
  _jq_to_file \
    "Failed to update \"$CLAUDE_JSON\"; existing file may contain invalid JSON. Fix or remove it to apply settings." \
    -s --argjson trust "$trust_projects" \
    '
      .[0] as $existing | .[1] as $overlay |
      # Replace top-level keys from overlay (mcpServers etc.), deep-merge .projects.
      ($existing + ($overlay | del(.projects))) | .projects = (($existing.projects // {}) * ($overlay.projects // {}) * $trust)
    ' "$CLAUDE_JSON" "$OVERLAY_FILE"
else
  _jq_to_file \
    "Failed to create \"$CLAUDE_JSON\" from overlay; jq returned an error." \
    --argjson trust "$trust_projects" \
    '. + {projects: $trust}' "$OVERLAY_FILE"
fi

[ -f "$CLAUDE_JSON" ] && $DRY_RUN_CMD chmod 600 "$CLAUDE_JSON"
