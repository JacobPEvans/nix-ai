# Qwen Code

[Qwen Code](https://github.com/QwenLM/qwen-code) is Alibaba's terminal
coding agent — Claude-Code-style UX for Qwen3-Coder and any
OpenAI/Anthropic/Gemini-compatible endpoint. Apache-2.0.

## What it manages

- A soft assertion that the brew-installed `qwen` binary is on PATH
  (when `installVia = "brew"`, the default on darwin). The actual brew
  install lives in nix-darwin's `homebrew.brews`, sourced from
  nix-ai's `lib.brewFormulae` flake output.
- Optional npm-based install (`installVia = "npm"`) for hosts without
  Homebrew — pre-warms `@qwen-code/qwen-code` into
  `~/.local/share/npm/` and provides a Nix-managed wrapper on PATH.
- A generated `~/.qwen/settings.json` wired to local llama-swap (or
  Bifrost) with one provider entry per capability-class alias from
  `services.aiStack.models`. Default startup model is the `coding`
  class.
- Doppler-wrapped `d-qwen` shell alias (declared in
  `modules/ai-aliases.zsh`) for sessions that need cloud-provider keys
  (Dashscope, OpenRouter, OpenAI, etc.).

## Install matrix

| Order | Source | Implementation status |
| --- | --- | --- |
| 1 | nixpkgs | Not packaged; option exists for forward compatibility |
| 2 | Homebrew (`qwen-code`) | **Default** — formula lives in nix-darwin's `homebrew.brews` |
| 3 | npm (`@qwen-code/qwen-code`) | Implemented as fallback |

Per the repo's install-order rule. Brew is the right home today —
bottled, ~9k installs/30d, Apache-2.0, deps are `node` + `ripgrep`
(both already common).

## Routing

Defaults to local MLX via llama-swap (`http://127.0.0.1:11434/v1`).
Switch to Bifrost (`http://localhost:30080/v1`) by setting
`programs.qwen-code.routing = "bifrost"`.

```nix
programs.qwen-code = {
  enable = true;
  routing = "llama-swap";  # default
  model = "coding";        # capability-class alias
};
```

For cloud-provider sessions, use `d-qwen` (Doppler-injected from
`ai-ci-automation/prd`).

## Adding cloud providers

`programs.qwen-code.extraSettings` is deep-merged into
`~/.qwen/settings.json`. Example:

```nix
programs.qwen-code.extraSettings = {
  modelProviders = [
    {
      name = "dashscope";
      protocol = "openai";
      baseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1";
      envKey = "DASHSCOPE_API_KEY";
      models = [ { name = "qwen3.6-coder-plus"; } ];
    }
  ];
};
```

The base `mlx-local-llama-swap` provider is preserved; new providers
are appended.

## Version pin

Pinned in `vars/ai-stack.nix` under `cliVersions.qwen-code`. Renovate
bumps the pin via the `# renovate: datasource=github-releases
depName=QwenLM/qwen-code` comment hint. The brew install resolves to
its own bottle version on each `brew update`; the pin in
`cliVersions` is documentation of the expected version.
