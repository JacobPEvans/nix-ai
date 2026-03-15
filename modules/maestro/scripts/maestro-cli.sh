#!/usr/bin/env bash
# Maestro CLI Wrapper
#
# Invokes Maestro Electron app in CLI mode for automated playbook execution.
# The Maestro app supports headless CLI commands for scheduled automation.
#
# Usage: maestro-cli <args...>  # passes all arguments to Maestro CLI

set -euo pipefail

# Path to Maestro Electron app
MAESTRO_APP="@maestroApp@"

# Verify Maestro is installed
if [ ! -x "$MAESTRO_APP" ]; then
  echo "Error: Maestro not found at '$MAESTRO_APP'" >&2
  echo "Please install Maestro from: https://www.maestro.app" >&2
  exit 1
fi

# Pass all arguments to Maestro CLI
exec "$MAESTRO_APP" "$@"
