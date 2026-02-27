#!/usr/bin/env python3
"""
Tests for keychain_error_handler module.
"""

import json
import tempfile
from pathlib import Path

from keychain_error_handler import emit_keychain_error_event


def test_emit_keychain_error_event():
    """Test emitting a keychain error event."""
    with tempfile.TemporaryDirectory() as tmpdir:
        events_log = Path(tmpdir) / "events.jsonl"

        event = emit_keychain_error_event(
            events_log,
            run_id="test-run-123",
            repo="test-repo",
            service="bws-claude-automation",
            account="user@example.com",
            exit_code=1,
            error_message="keychain item not found",
        )

        # Verify event structure
        assert event["event"] == "keychain_error"
        assert event["run_id"] == "test-run-123"
        assert event["repo"] == "test-repo"
        assert event["service"] == "bws-claude-automation"
        assert event["account"] == "user@example.com"
        assert event["exit_code"] == 1
        assert event["error_message"] == "keychain item not found"
        assert "timestamp" in event

        # Verify event was written to log
        assert events_log.exists()
        with open(events_log) as f:
            logged = json.loads(f.read().strip())
            assert logged == event


def test_emit_keychain_error_event_no_account():
    """Test emitting a keychain error event without account."""
    with tempfile.TemporaryDirectory() as tmpdir:
        events_log = Path(tmpdir) / "events.jsonl"

        event = emit_keychain_error_event(
            events_log,
            run_id="test-run-456",
            repo="test-repo",
            service="bws-token",
            account=None,
            exit_code=127,
            error_message="security command not found",
        )

        # Verify account defaults to "unknown"
        assert event["account"] == "unknown"
        assert event["exit_code"] == 127

        # Verify event was written to log
        assert events_log.exists()
        with open(events_log) as f:
            logged = json.loads(f.read().strip())
            assert logged == event


if __name__ == "__main__":
    test_emit_keychain_error_event()
    test_emit_keychain_error_event_no_account()
    print("All tests passed!")
