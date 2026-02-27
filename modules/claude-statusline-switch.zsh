# Claude Code Statusline SSH Detection
#
# Automatically switches between full and mobile statusline configs
# based on whether the session is via SSH or local terminal.
#
# Mobile config: Single-line, minimal (dir + reset timer)
# Full config: Multi-line with all features
#
# Run at shell startup to set Config.toml symlink appropriately.

_claude_statusline_switch() {
  local statusline_dir="$HOME/.claude/statusline"
  local config_link="$statusline_dir/Config.toml"
  local config_full="$statusline_dir/config-full.toml"
  local config_mobile="$statusline_dir/config-mobile.toml"

  # Ensure directory exists
  [[ -d "$statusline_dir" ]] || return 0

  # Determine which config to use, defaulting to full
  local target_config="$config_full"
  if [[ (-n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY") && -f "$config_mobile" ]]; then
    # SSH session with mobile config available
    target_config="$config_mobile"
  fi

  # Update symlink if target exists and link is incorrect or missing
  if [[ -f "$target_config" && "$(readlink "$config_link" 2>/dev/null)" != "$target_config" ]]; then
    ln -sf "$target_config" "$config_link"
  fi
}

# Run at shell startup
_claude_statusline_switch
