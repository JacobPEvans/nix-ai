# cecli — Maintained Aider Fork

[`cecli`](https://github.com/cecli-dev/cecli) is an actively maintained
fork of [Aider](https://github.com/paul-gauthier/aider) (PyPI:
`cecli-dev`). Drop-in replacement — the same UX, the same `.aider`-style
yaml config, plus an `aider-ce` entry point for muscle memory.

This module replaced `programs.aider` after upstream Aider stopped
seeing maintenance. The previous module's option surface is preserved
under `programs.cecli` to ease migration.

## What it manages

- Pre-warmed `cecli-dev` install via `uv tool install` at
  home-manager activation time, version-pinned through
  `vars/ai-stack.nix#cliVersions.cecli`.
- A nix-managed `cecli` wrapper on PATH that exec's the uvx-installed
  binary, so `which cecli` returns a deterministic store-path entry.
- Three read-only generated config files — `~/.cecli.conf.yml`,
  `~/.cecli/cecli-meta.json`, `~/.cecli/cecli-settings.yml` — wired
  to the local MLX endpoint and the capability-class registry.
- Doppler-wrapped `d-cecli` shell alias (declared in
  `modules/ai-aliases.zsh`) for sessions that need cloud-provider keys.

## Why uvx (and not nixpkgs / homebrew)

Per the repo install-order rule:

1. nixpkgs (if available)
2. Homebrew (if available)
3. uvx / npm as last resort

cecli is currently published to PyPI only — no nixpkgs derivation, no
Homebrew formula. uvx is the only sane path. As a bonus, uvx installs
in user-space so we sidestep the macOS Nix sandbox SIGKILL/SIGTRAP
issues that plague aider's deep ML transitive deps (sounddevice,
soundfile, pydub, etc.) when built in the nix sandbox.

The `installVia` option exists for forward compatibility — flip to
`"nixpkgs"` or `"brew"` once upstream packaging arrives.

## Routing

Defaults to local MLX via llama-swap (`http://127.0.0.1:11434/v1`),
no API keys required.

```nix
programs.cecli = {
  enable = true;
  routing = "llama-swap";   # default; alternative: "bifrost"
  model = "openai/default"; # capability-class alias from services.aiStack.models
};
```

For cloud-provider sessions, use the Doppler-injected `d-cecli` shell
alias — it loads `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, etc. from
`ai-ci-automation/prd`.

## Files written

| Path | Purpose |
| --- | --- |
| `~/.cecli.conf.yml` | Main config (read-only Nix-store symlink) |
| `~/.cecli/cecli-meta.json` | LiteLLM model metadata (context limits, costs) |
| `~/.cecli/cecli-settings.yml` | Per-model edit format + streaming overrides |

## Version pin

Pinned in `vars/ai-stack.nix` under `cliVersions.cecli`. Renovate bumps
the version via the `# renovate: datasource=pypi depName=cecli-dev`
comment hint. The activation hook re-runs `uv tool install --upgrade`
on every `darwin-rebuild switch` and is idempotent.
