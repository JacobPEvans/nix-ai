#!/usr/bin/env bash
# Create WakaTime config once with a placeholder API key.
# Sourced from default.nix activation with WAKATIME_CFG set in environment.

if [ ! -f "$WAKATIME_CFG" ]; then
  $DRY_RUN_CMD cat > "$WAKATIME_CFG" <<'EOF'
[settings]
api_key = waka_YOUR-API-KEY-HERE
EOF
  $DRY_RUN_CMD chmod 600 "$WAKATIME_CFG"
  echo "Created $WAKATIME_CFG with placeholder API key"
  echo "Edit this file and replace waka_YOUR-API-KEY-HERE with your real key"
  echo "Get your API key from: https://wakatime.com/settings/account"
else
  echo "WakaTime config already exists at $WAKATIME_CFG (not overwriting)"
fi
