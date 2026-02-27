# Auto-Claude Testing Documentation

Testing procedures for the auto-claude.sh autonomous maintenance script.

## Prerequisites

- zsh shell available
- Claude CLI installed (`claude` command in PATH)
- jq installed for JSON processing
- gh CLI installed for GitHub operations (optional but recommended)
- Deployed scripts via home-manager (`darwin-rebuild switch`)

## Basic Validation Tests

### 1. Syntax Validation

Verify the script has valid zsh syntax:

```bash
zsh -n modules/home-manager/ai-cli/claude/auto-claude.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

### 2. Usage Message

Run without arguments to verify usage message:

```bash
zsh modules/home-manager/ai-cli/claude/auto-claude.sh
```

Expected output:

```text
Usage: /path/to/auto-claude.sh <target_dir> <max_budget_usd> [log_dir]
```

Exit code: 1

### 3. Invalid Directory Error

Test directory validation:

```bash
zsh modules/home-manager/ai-cli/claude/auto-claude.sh /nonexistent 10
```

Expected output:

```text
Error: Directory /nonexistent does not exist.
```

Exit code: 1

### 4. Invalid Budget Error (Negative)

Test budget validation with negative number:

```bash
zsh modules/home-manager/ai-cli/claude/auto-claude.sh /tmp -5
```

Expected output:

```text
Error: MAX_BUDGET_USD must be a positive number, got: -5
```

Exit code: 1

### 5. Decimal Budget Validation

Test that decimal budgets are accepted:

```bash
zsh modules/home-manager/ai-cli/claude/auto-claude.sh /tmp 0.5 2>&1 | head -5
```

Expected: Script starts executing (shows Claude initialization output)

## Deployed Script Tests

After `darwin-rebuild switch`, verify deployment:

### 1. Script Deployment

```bash
ls -la ~/.claude/scripts/auto-claude.sh ~/.claude/scripts/orchestrator-prompt.txt
```

Expected: Both files exist as symlinks to nix store paths

### 2. Executable Permissions

```bash
test -x ~/.claude/scripts/auto-claude.sh && echo "Executable OK"
```

Expected: `Executable OK`

### 3. LaunchAgent Registration

```bash
launchctl list | grep com.claude.auto-claude
```

Expected: One or more auto-claude agents listed (if autoClaude.enable = true)

## Integration Test (Live Run)

To test a live run with minimal budget:

```bash
~/.claude/scripts/auto-claude.sh ~/git/test-repo 0.10 /tmp/auto-claude-test
```

This will:

1. Source shell configs for environment
2. Load orchestrator prompt
3. Start Claude with the specified budget
4. Log output to /tmp/auto-claude-test/

### Verify Log Output

```bash
ls -la /tmp/auto-claude-test/
cat /tmp/auto-claude-test/summary.log
```

## Slack Notification Tests

Auto-Claude uses the Python notifier with Slack SDK for rich notifications.
Channels are stored per-repo in the macOS automation keychain.

### Slack Prerequisites

1. Slack bot token in Bitwarden Secrets Manager (secret: `SLACK_BOT_TOKEN`)
2. Per-repo channel IDs in automation keychain:
   - `SLACK_CHANNEL_ID_NIX`
   - `SLACK_CHANNEL_ID_AI_ASSISTANT_INSTRUCTIONS`
3. BWS config at `~/.config/bws/.env`

### 1. Unlock Automation Keychain

The automation keychain must be unlocked for headless operations:

```bash
security unlock-keychain -p "" ~/Library/Keychains/automation.keychain-db
```

### 2. Verify Channel IDs in Keychain

Check that channels are retrievable (output suppressed for security):

```bash
security find-generic-password -s "SLACK_CHANNEL_ID_NIX" -a "ai-cli-coder" -w >/dev/null && echo "NIX: FOUND"
security find-generic-password -s "SLACK_CHANNEL_ID_AI_ASSISTANT_INSTRUCTIONS" -a "ai-cli-coder" -w >/dev/null && echo "AI: FOUND"
```

### 3. Run Validation Test Script

```bash
PYTHONPATH=~/.claude/scripts /etc/profiles/per-user/$USER/bin/python3 \
  ~/.claude/scripts/test-slack-notifications.py
```

### 4. Send Test Messages to Each Channel

Define a helper function to avoid repetition:

```bash
send_test_notification() {
  local repo_key="$1"
  local repo_name="$2"
  local channel
  channel=$(security find-generic-password -s "SLACK_CHANNEL_ID_${repo_key}" -a "ai-cli-coder" -w)
  if [[ -z "$channel" ]]; then
    echo "Channel for ${repo_key} not found in keychain." >&2
    return 1
  fi

  PYTHONPATH=~/.claude/scripts /etc/profiles/per-user/$USER/bin/python3 \
    ~/.claude/scripts/auto-claude-notify.py run_started \
    --repo "$repo_name" --budget "0.01" --run-id "test-$(date +%s)" \
    --channel "$channel" && echo "✓ ${repo_key} channel test sent"
}

# Test NIX channel
send_test_notification "NIX" "test-nix"

# Test AI-ASSISTANT-INSTRUCTIONS channel
send_test_notification "AI_ASSISTANT_INSTRUCTIONS" "test-ai"
```

### 5. End-to-End LaunchD Test

This tests the full launchd-initiated flow:

```bash
# Ensure keychain is unlocked first
security unlock-keychain -p "" ~/Library/Keychains/automation.keychain-db

# Kickstart the launchd agent
launchctl kickstart gui/$(id -u)/com.claude.auto-claude-nix

# Monitor logs
tail -f ~/.claude/logs/launchd-nix.log

# Check for errors
tail ~/.claude/logs/launchd-nix.err
```

**Success indicators:**

- Log shows `slack_enabled: "true"` in run_started event
- Slack channel receives "Run Started" notification
- No `ModuleNotFoundError` in error log

## Troubleshooting

### Script Not Found

If `claude` command not found after launchd execution:

1. Check PATH in launchd agent:

   ```bash
   cat ~/Library/LaunchAgents/com.claude.auto-claude-*.plist | grep -A5 PATH
   ```

2. Verify PATH includes `/run/current-system/sw/bin`

### Orchestrator Prompt Missing

If prompt file not found:

```bash
ls -la ~/.claude/scripts/orchestrator-prompt.txt
```

If missing, run `darwin-rebuild switch` to deploy.

### API Authentication Failures

If headless auth fails:

1. Verify apiKeyHelper is enabled
2. Check BWS secret access:

   ```bash
   ~/.local/bin/claude-api-key-helper
   ```

3. Verify keychain token:

   ```bash
   security find-generic-password -s bws-claude-automation -w
   ```

### Slack Notifications Not Sending

**Symptom**: `ModuleNotFoundError: No module named 'slack_sdk'`

**Cause**: LaunchD uses wrong Python environment

**Fix**: Rebuild to update launchd plist with per-user profile path:

```bash
darwin-rebuild switch --flake ~/.config/nix
```

Verify the plist PATH includes per-user profile:

```bash
grep PATH ~/Library/LaunchAgents/com.claude.auto-claude-nix.plist
# Should show: /etc/profiles/per-user/<username>/bin at the start
```

**Symptom**: Keychain access denied (error -25308)

**Cause**: Automation keychain is locked

**Fix**: Unlock the keychain:

```bash
security unlock-keychain -p "" ~/Library/Keychains/automation.keychain-db
```

**Symptom**: Channel not found in keychain

**Cause**: Missing per-repo channel entry

**Fix**: Add the channel to automation keychain:

```bash
security add-generic-password -a "ai-cli-coder" \
  -s "SLACK_CHANNEL_ID_<REPO_NAME>" \
  -w "<channel_id>" \
  ~/Library/Keychains/automation.keychain-db
```

Replace `<REPO_NAME>` with uppercase repo name (dashes/dots to underscores).
