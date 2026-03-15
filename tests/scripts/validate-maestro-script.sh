#!/usr/bin/env bash
# Validate the maestro-cli script content integrity.
# Called from tests/nix/maestro-script.nix.
# Usage: validate-maestro-script.sh <script-path>
set -euo pipefail

testScript="$1"
echo "Validating maestro-cli script..."

# Verify @maestroApp@ placeholder was substituted
if grep -q "@maestroApp@" "$testScript"; then
  echo "FAIL: @maestroApp@ placeholder was NOT substituted"
  exit 1
fi

# Verify the test path appears in the script
if ! grep -q "/test/path/to/Maestro" "$testScript"; then
  echo "FAIL: substituted path not found in script"
  exit 1
fi

# Verify shebang
if ! head -1 "$testScript" | grep -q "#!/usr/bin/env bash"; then
  echo "FAIL: missing or incorrect shebang"
  exit 1
fi

# Verify strict mode
if ! grep -q "set -euo pipefail" "$testScript"; then
  echo "FAIL: missing set -euo pipefail"
  exit 1
fi

# Verify exec command is present
if ! grep -q 'exec.*MAESTRO_APP' "$testScript"; then
  echo "FAIL: missing exec command"
  exit 1
fi

# Verify error handling exists
if ! grep -q 'Maestro not found' "$testScript"; then
  echo "FAIL: missing error message"
  exit 1
fi

echo "Maestro script: substitution, shebang, strict mode, exec, error handling verified"
