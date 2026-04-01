#!/usr/bin/env bash
# Restart llama-swap proxy (preloads default model).
# Usage: mlx-default

launchctl kickstart -k "gui/$(id -u)/${MLX_LAUNCHD_LABEL:?}"
echo "Default model restored."
