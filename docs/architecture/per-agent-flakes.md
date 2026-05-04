# Per-Agent Module / Flake Pattern

## Why this exists

nix-ai grew organically: Claude, Gemini, Codex, fabric, and (formerly)
Aider all live as sibling modules under `modules/`. Each has its own
shape, its own opinions about install source, its own depth of
configuration. Adding a new agent means re-deciding all of that.

The aider→cecli migration plus the addition of qwen-code (2026-05-04)
established a uniform layout that future agents — and existing ones,
when they're touched — should follow. The end-state goal is a clean
extraction: each agent module becomes its own small flake exposing a
home-manager module, so users can opt in/out per agent without pulling
the entire nix-ai surface area.

## Module layout

```text
modules/<agent>/
├── default.nix     ← module entry: imports + cfg.enable wiring
├── options.nix     ← user-facing options (model, routing, edit format, etc.)
├── packages.nix    ← install-source selection (nixpkgs | brew | uvx | npm)
├── settings.nix    ← config-file generation (consumes vars/ai-stack.nix)
├── activation.nix  ← (optional) pre-warm install + cache hygiene
└── README.md       ← what the agent does, install matrix, opt-in knobs
```

Reference implementations:

- `modules/cecli/` — uvx install path; mirrors aider's option surface.
- `modules/qwen-code/` — brew install path with npm fallback;
  separate config file (`~/.qwen/settings.json`).

Existing modules (`modules/claude/`, `modules/gemini/`, `modules/codex/`,
`modules/fabric/`) predate this pattern. They work fine and are not
being refactored in the same PR — that's a follow-up sweep tracked
separately.

## Install-order rule

Per the repo's `nix-package-placement` rule:

1. **nixpkgs** if available (deterministic, GC-safe, cached binary)
2. **Homebrew** if available, declared via nix-darwin's `homebrew.brews`
3. **uvx / npm** as last resort for tools the first two don't ship

Each `packages.nix` exposes a `programs.<agent>.installVia` enum option
whose `default` reflects the preferred source for that agent today.
Other values are accepted with assertions when they're not yet
implemented, providing forward compatibility without surprise behavior.

## Settings consumption — the central registry

All agents read from the same source of truth: `vars/ai-stack.nix`.
That file holds `models` (capability-class registry), `endpoints`,
`nodeports`, and `cliVersions`. nix-side consumers `import` it; non-nix
consumers read `~/.config/ai-stack/registry.json` (written every
rebuild from the same data).

A new agent must NOT hardcode model IDs, endpoint URLs, or version
strings. Reach into the registry instead.

## Brew-installed agents

Brew lives in nix-darwin (`homebrew.brews`), not home-manager. The
contract:

1. Agent's `packages.nix` adds the formula name to a list visible from
   the flake.
2. nix-ai's `flake.nix` aggregates those into the `lib.brewFormulae`
   output.
3. nix-darwin's host config consumes `inputs.nix-ai.lib.brewFormulae`
   and merges into `homebrew.brews`.
4. Agent's module includes a soft activation-time check that the
   binary is on PATH (warns rather than aborts, so users get a clear
   pointer when they enable the home-manager module without the
   companion nix-darwin rebuild).

`qwen-code` is the reference for this pattern.

## uvx-installed agents

uvx installs in user-space (`~/.local/share/uv/`), so the binary is
not directly in any Nix store path. The module:

1. Pre-warms the install at home-manager activation:
   `uv tool install --upgrade --native-tls --python python3.12 "<pkg>==<ver>"`
   reading the version from `vars/ai-stack.nix#cliVersions.<pkg>`.
2. Provides a `pkgs.writeShellScriptBin "<binary>"` wrapper that
   exec's `~/.local/bin/<binary>`. This keeps `which <binary>`
   deterministic — it always resolves to a Nix-managed wrapper —
   without paying the cost of building the package in nix.
3. Uses a `# renovate: datasource=pypi depName=<pkg>` comment hint on
   the version pin so dependency bumps are managed automatically.

`cecli` is the reference for this pattern.

### Known uvx weaknesses + mitigations

| Weakness | Mitigation |
| --- | --- |
| Not GC'd by Nix; `~/.local/share/uv/` accumulates | `uv cache prune` documented in module READMEs; future weekly launchd job |
| First-invocation network for download | Activation pre-warm makes the binary available post-rebuild |
| Updates not declarative / Renovate-blind | Version pin in `vars/ai-stack.nix` with renovate hint comment |
| Stale interpreter refs after Python upgrade | Pin `--python python3.12` explicitly; activation re-installs on Python bump |
| Wrapper indirection (~/.local/bin → uv) | `writeShellScriptBin` wrapper gives a deterministic Nix-managed PATH entry |

## npm-installed agents (fallback)

Same pattern as uvx but with `npm install --prefix ~/.local/share/npm`
instead of `uv tool install`. Used only when an agent has neither a
nixpkgs derivation nor a Homebrew formula AND its upstream is npm
(common for JS/TS-based CLIs). qwen-code's `installVia = "npm"` branch
is the reference.

## Path to standalone flakes

Each per-agent module is structured so it can graduate to its own flake
with no behavior change. The graduation recipe:

1. `git mv modules/<agent>/ ../nix-ai-<agent>/` into a new repo.
2. Add a minimal `flake.nix` that exports `homeManagerModules.default`
   from `default.nix`.
3. Declare `inputs.nix-ai.url = "github:JacobPEvans/nix-ai"` so the
   extracted flake still consumes `vars/ai-stack.nix` as the central
   registry.
4. In nix-ai's `flake.nix`, replace the in-tree import with the new
   flake input.

The central registry stays in nix-ai. Individual agents extract; the
config layer doesn't fragment.

### When to extract

Extract when one of:

- The agent has its own release cadence that doesn't align with
  nix-ai's (e.g., Claude Code's near-daily updates).
- The module grew its own non-trivial dependencies that pollute
  nix-ai's flake lock.
- A user wants to opt out of the rest of nix-ai but still use this
  one agent.

Don't extract preemptively. cecli and qwen-code stay in-tree until
one of these triggers fires.

## Migration checklist for existing modules

When refactoring `modules/claude/`, `modules/gemini/`, `modules/codex/`,
or `modules/fabric/` to this pattern:

- [ ] Split `default.nix` into the 4-5 standard sub-files.
- [ ] Add `programs.<agent>.installVia` option, even if only one value
      is implemented today.
- [ ] Remove any hardcoded model IDs / endpoint URLs / version strings
      that should be in `vars/ai-stack.nix` (or already are).
- [ ] If the agent's preferred install source is brew, surface it via
      `lib.brewFormulae`.
- [ ] If the agent has an npm/uvx install path, add the appropriate
      pre-warm activation + version pin.
- [ ] Write a README mirroring the cecli + qwen-code shape (What it
      manages, Install matrix, Routing, Version pin).
- [ ] Verify with `nix flake check` and a real `darwin-rebuild switch`.
