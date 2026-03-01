#!/usr/bin/env python3
"""
Claude API Key Helper - Retrieves Claude OAuth token for headless authentication.

Used by Claude Code's apiKeyHelper mechanism for headless authentication
(cron jobs, CI/CD pipelines, launchd agents, etc.)

Configuration: ~/.config/bws/.env (see bws_helper.py)
"""

import os
import sys
from pathlib import Path

# Import bws_helper from same directory
sys.path.insert(0, str(Path(__file__).parent))
import bws_helper

if __name__ == "__main__":
    try:
        # Write to fd 1 (stdout) directly — this is Claude Code's apiKeyHelper,
        # which emits the OAuth token for capture by the Claude CLI.
        os.write(1, (bws_helper.get_secret("CLAUDE_OAUTH_TOKEN") + "\n").encode())
    except (FileNotFoundError, ValueError, RuntimeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
