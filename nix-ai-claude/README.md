# nix-ai-claude

Claude-specific Home Manager module stack extracted from `nix-ai`.

It is designed to work in two modes:

- standalone: import `nix-ai-claude.homeManagerModules.default` directly
- embedded: let `nix-ai` re-export or import the Claude module as one part of a larger AI tool stack

## Exports

- `homeManagerModules.default`
- `homeManagerModules.claude`
- `lib.ci.claudeSettingsJson`
- `lib.claude-settings`
- `lib.claude-registry`

## Usage

```nix
{
  inputs.nix-ai-claude.url = "github:JacobPEvans/nix-ai-claude";
}
```

```nix
sharedModules = [ nix-ai-claude.homeManagerModules.default ];
```

This staged copy lives inside `nix-ai` so the extraction can be validated before it is moved to its own repository.
