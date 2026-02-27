#!/usr/bin/env python3
"""
Test Script: Slack Notification Validation

Validates that auto-claude Slack notifications are properly configured.
Run this script to verify Slack setup before relying on notifications.

Usage:
    python3 test-slack-notifications.py           # Run all checks
    python3 test-slack-notifications.py --send    # Also send a test message

Exit codes:
    0 = All tests passed
    1 = Configuration issue (fixable)
    2 = Dependency missing
"""

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from auto_claude_utils import (
    get_keychain_password,
    get_repo_name,
    load_bws_env,
    sanitize_repo_name,
)


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    NC = "\033[0m"


class TestResults:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.warnings = 0

    def pass_(self, msg: str):
        print(f"{Colors.GREEN}✓ PASS{Colors.NC}: {msg}")
        self.passed += 1

    def fail(self, msg: str):
        print(f"{Colors.RED}✗ FAIL{Colors.NC}: {msg}")
        self.failed += 1

    def warn(self, msg: str):
        print(f"{Colors.YELLOW}⚠ WARN{Colors.NC}: {msg}")
        self.warnings += 1


def main():
    parser = argparse.ArgumentParser(description="Test Slack notification configuration")
    parser.add_argument("--send", action="store_true", help="Send a test message to Slack")
    args = parser.parse_args()

    results = TestResults()
    home = Path.home()

    print("==============================================")
    print("Auto-Claude Slack Notification Test")
    print("==============================================")
    print()

    # --- Test 1: Python packages ---
    print("1. Checking Python packages...")
    try:
        import slack_sdk  # noqa: F401

        results.pass_("slack_sdk package available")
    except ImportError:
        results.fail("slack_sdk package NOT available")

    try:
        import keyring  # noqa: F401

        results.pass_("keyring package available")
    except ImportError:
        results.fail("keyring package NOT available")

    # --- Test 2: BWS config ---
    print()
    print("2. Checking BWS configuration...")
    bws_env = home / ".config/bws/.env"
    if bws_env.exists():
        results.pass_(f"BWS config found: {bws_env}")
        config = load_bws_env()

        if "BWS_KEYCHAIN_ACCOUNT" in config:
            results.pass_(f"BWS account configured: {config['BWS_KEYCHAIN_ACCOUNT']}")
        else:
            results.fail("BWS_KEYCHAIN_ACCOUNT not set")

        if "BWS_SECRET_SLACK_BOT_TOKEN" in config:
            results.pass_("SLACK_BOT_TOKEN secret mapping configured")
        else:
            results.fail("BWS_SECRET_SLACK_BOT_TOKEN not set")
    else:
        results.fail(f"BWS config NOT found: {bws_env}")
        config = {}

    # --- Test 3: Notifier script ---
    print()
    print("3. Checking notifier script...")
    notifier = home / ".claude/scripts/auto-claude-notify.py"
    if notifier.exists() and os.access(notifier, os.X_OK):
        results.pass_(f"Notifier script found: {notifier}")
    else:
        results.fail(f"Notifier script NOT found or not executable: {notifier}")

    # --- Test 4: Slack token retrieval ---
    print()
    print("4. Checking Slack token retrieval...")
    try:
        # Import bws_helper from the scripts directory
        sys.path.insert(0, str(home / ".claude/scripts"))
        import bws_helper

        token = bws_helper.get_secret("SLACK_BOT_TOKEN")
        if token.startswith("xoxb-"):
            results.pass_("Slack bot token retrieved successfully (xoxb-...)")
        else:
            results.fail("Slack token has unexpected format (should start with xoxb-)")
    except Exception as e:
        results.fail(f"Could not retrieve Slack token: {e}")

    # --- Test 5: Slack channel resolution ---
    print()
    print("5. Checking Slack channel resolution...")

    bws_account = config.get("BWS_KEYCHAIN_ACCOUNT")
    fallback_channel = config.get("SLACK_DEFAULT_CHANNEL")

    # Test repo-specific channel lookup
    test_repos = [
        str(home / ".config/nix"),
        str(home / "git/ai-assistant-instructions/main"),
    ]

    for test_repo in test_repos:
        if Path(test_repo).exists():
            # Use get_repo_name from utils (handles worktrees properly)
            repo_name = get_repo_name(test_repo)
            print(f"   Testing: {test_repo}")
            print(f"   Detected repo name: {repo_name}")

            sanitized = sanitize_repo_name(repo_name)
            keychain_key = f"SLACK_CHANNEL_ID_{sanitized}"

            channel = get_keychain_password(keychain_key, bws_account)
            if channel:
                results.pass_(f"Repo-specific channel: {keychain_key} -> {channel}")
            else:
                results.warn(f"No repo-specific channel for {keychain_key}")

    # Check fallback
    if fallback_channel:
        results.pass_(f"Fallback channel configured: {fallback_channel}")
    else:
        results.fail("No SLACK_DEFAULT_CHANNEL - notifications will fail for unconfigured repos")

    # --- Test 6: List all keychain channels ---
    print()
    print("6. Keychain Slack channels found:")
    try:
        result = subprocess.run(["security", "dump-keychain"], capture_output=True, text=True)
        for line in result.stdout.splitlines():
            if "SLACK_CHANNEL_ID" in line and "svce" in line:
                # Extract service name
                if '<blob>="' in line:
                    service = line.split('<blob>="')[1].split('"')[0]
                    print(f"   • {service}")
    except subprocess.CalledProcessError:
        results.warn("Could not list keychain entries")

    # --- Test 7: Optional send test ---
    if args.send:
        print()
        print("7. Sending test message to Slack...")
        test_channel = fallback_channel
        if not test_channel:
            results.fail("No channel available for test message")
        else:
            run_id = f"test-{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            print(f"   Channel: {test_channel}")
            print(f"   Run ID: {run_id}")

            try:
                result = subprocess.run(
                    [
                        sys.executable,
                        str(notifier),
                        "run_started",
                        "--repo",
                        "test-validation",
                        "--budget",
                        "0.01",
                        "--run-id",
                        run_id,
                        "--channel",
                        test_channel,
                    ],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                results.pass_(f"Test message sent! Check Slack. Thread TS: {result.stdout.strip()}")
            except subprocess.CalledProcessError as e:
                results.fail(f"Failed to send test message: {e.stderr}")

    # --- Summary ---
    print()
    print("==============================================")
    print("Summary")
    print("==============================================")
    print(f"Passed:   {Colors.GREEN}{results.passed}{Colors.NC}")
    print(f"Failed:   {Colors.RED}{results.failed}{Colors.NC}")
    print(f"Warnings: {Colors.YELLOW}{results.warnings}{Colors.NC}")
    print()

    if results.failed > 0:
        print(f"{Colors.RED}Some tests failed. Fix the issues above.{Colors.NC}")
        sys.exit(1)
    elif results.warnings > 0:
        print(f"{Colors.YELLOW}All critical tests passed but there are warnings.{Colors.NC}")
    else:
        print(f"{Colors.GREEN}All tests passed!{Colors.NC}")

    if not args.send:
        print()
        print("To send a test message, run with --send flag:")
        print(f"  python3 {__file__} --send")

    sys.exit(0)


if __name__ == "__main__":
    main()
