#!/usr/bin/env python3
"""
Claude API Key Helper - Retrieves Claude OAuth token for headless authentication.

Used by Claude Code's apiKeyHelper mechanism for headless authentication
(cron jobs, CI/CD pipelines, launchd agents, etc.)

Configuration: ~/.config/bws/.env (see bws_helper.py)
"""

import sys
from pathlib import Path

# Import bws_helper from same directory
sys.path.insert(0, str(Path(__file__).parent))
import bws_helper

if __name__ == "__main__":
    try:
        # This script is Claude Code's apiKeyHelper: it intentionally writes the
        # OAuth token to stdout so the Claude CLI can capture it for authentication.
        # The output goes to a pipe, not a log, so clear-text logging is not a concern.
        output = bws_helper.get_secret("CLAUDE_OAUTH_TOKEN")
        sys.stdout.write(output + "\n")
    except (FileNotFoundError, ValueError, RuntimeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
