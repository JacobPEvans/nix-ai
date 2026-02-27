#!/usr/bin/env python3
"""
BWS Helper - Fetch secrets from Bitwarden Secrets Manager via macOS Keychain.

Config: ~/.config/bws/.env (not in git)
Usage: python3 bws_helper.py CLAUDE_OAUTH_TOKEN  # prints secret value
"""

import functools
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import keyring


@functools.lru_cache(maxsize=1)
def load_env(path: Path = Path.home() / ".config/bws/.env") -> dict[str, str]:
    """Load .env file into dict (cached).

    Note: Cache is intentional - config should not change during script execution.
    Scripts are short-lived (seconds), so stale config is not a concern.
    """
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    config = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            if line.startswith("export "):
                line = line[7:]
            k, _, v = line.partition("=")
            key = k.strip()
            # Strip a single pair of matching surrounding quotes after trimming whitespace
            # This preserves legitimate leading/trailing quotes that are not delimiters
            raw = v.strip()
            if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ("'", '"'):
                value = raw[1:-1]
            else:
                value = raw
            if not value:
                raise ValueError(f"Empty value for key '{key}' in {path}")
            config[key] = value

    # Validate required keychain config keys are present
    required_keys = ["BWS_KEYCHAIN_SERVICE", "BWS_KEYCHAIN_ACCOUNT"]
    missing = [k for k in required_keys if k not in config]
    if missing:
        raise ValueError(f"Missing required config key(s) in {path}: {', '.join(missing)}")
    return config


def get_bws_token() -> str:
    """Get BWS access token from keychain."""
    cfg = load_env()
    service = cfg.get("BWS_KEYCHAIN_SERVICE")
    account = cfg.get("BWS_KEYCHAIN_ACCOUNT")
    if not service:
        raise ValueError("BWS_KEYCHAIN_SERVICE not in config")
    if not account:
        raise ValueError("BWS_KEYCHAIN_ACCOUNT not in config")
    token = keyring.get_password(service, account)
    if not token:
        raise RuntimeError(f"No keychain entry for BWS token (service='{service}', account='{account}')")
    return token


def bws_get(name_or_id: str) -> str:
    """Fetch secret from BWS by name or ID. Secret value flows directly to return."""
    env = {**os.environ, "BWS_ACCESS_TOKEN": get_bws_token()}

    # If not a UUID, resolve name to ID via list (metadata only, no secret values)
    if not _is_uuid(name_or_id):
        try:
            result = subprocess.run(
                ["bws", "secret", "list", "-o", "json"],
                capture_output=True,
                text=True,
                env=env,
                check=True,
            )
        except FileNotFoundError:
            raise RuntimeError("bws command not found. Install it from https://bitwarden.com/help/secrets-manager-cli/") from None
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to list bws secrets to find ID for '{name_or_id}': {e.stderr}") from e

        try:
            secrets = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Failed to parse bws secret list output: {e}") from e

        original_name = name_or_id
        for s in secrets:
            if s.get("key") == name_or_id:
                name_or_id = s["id"]
                break

        if not _is_uuid(name_or_id):
            raise ValueError(f"Secret '{original_name}' not found in BWS")

    # Fetch secret by ID - value goes straight from JSON to return
    try:
        result = subprocess.run(
            ["bws", "secret", "get", name_or_id, "-o", "json"],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
    except FileNotFoundError:
        raise RuntimeError("bws command not found. Install it from https://bitwarden.com/help/secrets-manager-cli/") from None
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"bws secret get failed for '{name_or_id}': {e.stderr}") from e

    try:
        return json.loads(result.stdout)["value"]
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse bws secret get output: {e}") from e
    except KeyError:
        raise RuntimeError(f"bws secret get returned JSON without 'value' key for '{name_or_id}'") from None


def _is_uuid(s: str) -> bool:
    """Check if string looks like a UUID."""
    return bool(re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', s, re.I))


def get_secret(key: str) -> str:
    """Get secret using config key (e.g., 'CLAUDE_OAUTH_TOKEN' -> BWS_SECRET_CLAUDE_OAUTH_TOKEN)."""
    cfg = load_env()
    name_or_id = cfg.get(f"BWS_SECRET_{key}")
    if not name_or_id:
        raise ValueError(f"BWS_SECRET_{key} not in config")
    return bws_get(name_or_id)


def get_keychain(service: str) -> str:
    """Get non-secret values from keychain (Slack channel IDs, etc.) using BWS account."""
    cfg = load_env()
    account = cfg.get("BWS_KEYCHAIN_ACCOUNT")
    if not account:
        raise ValueError("BWS_KEYCHAIN_ACCOUNT not in config")
    value = keyring.get_password(service, account)
    if not value:
        raise RuntimeError(f"No keychain entry (service='{service}', account='{account}')")
    return value


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: bws_helper.py <SECRET_KEY>", file=sys.stderr)
        sys.exit(1)
    print(get_secret(sys.argv[1].upper().replace("-", "_")))
