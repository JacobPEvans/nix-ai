#!/usr/bin/env python3
"""Seed llama-swap runtime config from the Nix-generated base config.

Called by home.activation on darwin-rebuild switch. Preserves
runtime-discovered models by only overwriting when the base config
has actually changed (tracked via .base-config-hash marker file).

Arguments:
  $1 - path to Nix-generated base config (immutable Nix store)
  $2 - path to mutable runtime config (read by llama-swap)
"""

import hashlib
import shutil
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        print(
            "Usage: seed-config.py <base-config> <runtime-config>", file=sys.stderr
        )
        sys.exit(1)

    base = Path(sys.argv[1])
    runtime = Path(sys.argv[2])
    runtime.parent.mkdir(parents=True, exist_ok=True)

    base_hash = hashlib.sha256(base.read_bytes()).hexdigest()
    marker = runtime.parent / ".base-config-hash"

    if not runtime.exists():
        shutil.copy2(base, runtime)
        marker.write_text(base_hash + "\n")
        print("Seeded llama-swap runtime config from Nix store")
        return

    prev_hash = marker.read_text().strip() if marker.exists() else ""

    if base_hash != prev_hash:
        shutil.copy2(base, runtime)
        marker.write_text(base_hash + "\n")
        print("Updated llama-swap runtime config (base config changed)")
    else:
        print("llama-swap runtime config unchanged (base hash matches)")


if __name__ == "__main__":
    main()
