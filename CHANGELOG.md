# Changelog

## [1.4.0](https://github.com/JacobPEvans/nix-ai/compare/v1.3.0...v1.4.0) (2026-03-14)


### Bug Fixes

* build pal-mcp-server as Nix derivation ([#157](https://github.com/JacobPEvans/nix-ai/issues/157)) ([7e5ab79](https://github.com/JacobPEvans/nix-ai/commit/7e5ab799c0ae56d7af12cfe2769988f780c61373))

## [1.3.0](https://github.com/JacobPEvans/nix-ai/compare/v1.2.0...v1.3.0) (2026-03-14)


### Features

* enable 1M context window models in model picker ([#155](https://github.com/JacobPEvans/nix-ai/issues/155)) ([73ae890](https://github.com/JacobPEvans/nix-ai/commit/73ae890e1b872af01dedd7dcab38b24740dbb914))

## [1.2.0](https://github.com/JacobPEvans/nix-ai/compare/v1.1.0...v1.2.0) (2026-03-13)


### Features

* add splunk-mcp-connect wrapper script ([#151](https://github.com/JacobPEvans/nix-ai/issues/151)) ([294abd1](https://github.com/JacobPEvans/nix-ai/commit/294abd13b211390518bd68a76166fbef1f78141f))

## [1.1.0](https://github.com/JacobPEvans/nix-ai/compare/v1.0.0...v1.1.0) (2026-03-13)


### Features

* add daily repo health audit agentic workflow ([#137](https://github.com/JacobPEvans/nix-ai/issues/137)) ([daa4a0e](https://github.com/JacobPEvans/nix-ai/commit/daa4a0ea05d5a828034d24377f187273763aecf9))
* add release-please automation ([#96](https://github.com/JacobPEvans/nix-ai/issues/96)) ([06fa54a](https://github.com/JacobPEvans/nix-ai/commit/06fa54ae068b3b43df85755059080ece10a1d4fc))
* add scheduled AI workflow callers ([#113](https://github.com/JacobPEvans/nix-ai/issues/113)) ([475114a](https://github.com/JacobPEvans/nix-ai/commit/475114a1cbf0c52609e9a5199cc62154b334304a))
* **ci:** add flake update workflow for upstream dispatch events ([#108](https://github.com/JacobPEvans/nix-ai/issues/108)) ([9e3e6d0](https://github.com/JacobPEvans/nix-ai/commit/9e3e6d00b83d802c60e5752294e8b2dd7e3022ca))
* **claude:** make effortLevel optional, add adaptive thinking env var ([#106](https://github.com/JacobPEvans/nix-ai/issues/106)) ([c26c599](https://github.com/JacobPEvans/nix-ai/commit/c26c599b19ef1d6a074689410e6cc33c4a893c8b))
* **claude:** make settings.json writable via activation-time merge ([#107](https://github.com/JacobPEvans/nix-ai/issues/107)) ([9af21f8](https://github.com/JacobPEvans/nix-ai/commit/9af21f8339078d0c69e3799bc0b32bf17ab596f9))
* disable automatic triggers on Claude-executing workflows ([ad7cef3](https://github.com/JacobPEvans/nix-ai/commit/ad7cef3bf6462486a2c2704697d5bd60fbfa0a59))
* expose gh-aw package, fix PAL hash, add nix-update to flake workflow ([#131](https://github.com/JacobPEvans/nix-ai/issues/131)) ([f519f98](https://github.com/JacobPEvans/nix-ai/commit/f519f98f63061bf25921bdcf9bf9dc7d7db931e7))
* migrate to ai-workflows suite groupings (v0.8.0) ([#102](https://github.com/JacobPEvans/nix-ai/issues/102)) ([4b6b806](https://github.com/JacobPEvans/nix-ai/commit/4b6b8068e955afbde551cb0c67a50129c3d83376))
* **open-webui:** add LaunchAgent for auto-start on login ([#110](https://github.com/JacobPEvans/nix-ai/issues/110)) ([d3f8460](https://github.com/JacobPEvans/nix-ai/commit/d3f84604e3373e3f799b9ed2a88c414c3d36174b))
* **pal:** set DEFAULT_MODEL to latest Gemini (gemini-3-pro-preview) ([#109](https://github.com/JacobPEvans/nix-ai/issues/109)) ([c540bda](https://github.com/JacobPEvans/nix-ai/commit/c540bda62de5712365e0638632e120ce3f506ae2))
* re-enable issue auto-resolve gated by ai:ready label ([#127](https://github.com/JacobPEvans/nix-ai/issues/127)) ([3342d6f](https://github.com/JacobPEvans/nix-ai/commit/3342d6fb105e714384c717248cf70f9dda78c6ad))
* show repo/worktree in statusline cwd instead of basename ([#129](https://github.com/JacobPEvans/nix-ai/issues/129)) ([5f4feb9](https://github.com/JacobPEvans/nix-ai/commit/5f4feb94b1cffa22fdec2316588d7e824f217443))
* switch to ClaudeCodeStatusLine (daniel3303) 2-line statusline ([#126](https://github.com/JacobPEvans/nix-ai/issues/126)) ([805b240](https://github.com/JacobPEvans/nix-ai/commit/805b240bf23815421f123b38d6f6d6093769b051)), closes [#103](https://github.com/JacobPEvans/nix-ai/issues/103)
* upgrade to Python 3.14 and add MLX inference server ([#142](https://github.com/JacobPEvans/nix-ai/issues/142)) ([60695d9](https://github.com/JacobPEvans/nix-ai/commit/60695d9dd1fc759541f806170099b3f42886c950))
* WakaTime Doppler injection, PAL flake pinning, GitHub MCP disabled ([#122](https://github.com/JacobPEvans/nix-ai/issues/122)) ([448417c](https://github.com/JacobPEvans/nix-ai/commit/448417cbbd6458b103a92fe1d0a7945a44a06928))


### Bug Fixes

* add concurrency groups to prevent duplicate PR creation ([#114](https://github.com/JacobPEvans/nix-ai/issues/114)) ([8c6a543](https://github.com/JacobPEvans/nix-ai/commit/8c6a54382db529bdb843bd00d6742ada92489f30))
* add diagnostic logging to doppler-mcp and check-pal-mcp health script ([#130](https://github.com/JacobPEvans/nix-ai/issues/130)) ([a88b266](https://github.com/JacobPEvans/nix-ai/commit/a88b26611db1deb81aa725d829253403df3d5410))
* **ci:** use [@v0](https://github.com/v0) floating tag for ai-workflows references ([#104](https://github.com/JacobPEvans/nix-ai/issues/104)) ([31d1d61](https://github.com/JacobPEvans/nix-ai/commit/31d1d61ceabde91c2cfe408605b5c70df478f64e))
* **ci:** use GitHub App token for release-please to trigger CI Gate ([#147](https://github.com/JacobPEvans/nix-ai/issues/147)) ([d5837bb](https://github.com/JacobPEvans/nix-ai/commit/d5837bb2aaa4e510212ab1691a5314dd344de7dd))
* correct best-practices permissions and add ref-scoped concurrency ([#115](https://github.com/JacobPEvans/nix-ai/issues/115)) ([197d1aa](https://github.com/JacobPEvans/nix-ai/commit/197d1aaea84a95a36b1173c7b7d734d7b1e66854))
* **deps:** remove manual input list from flake update workflow ([#118](https://github.com/JacobPEvans/nix-ai/issues/118)) ([cd7946d](https://github.com/JacobPEvans/nix-ai/commit/cd7946d0a2be24da35254abb0811be16a11ac30c))
* disable hash pinning for trusted actions, use version tags ([#116](https://github.com/JacobPEvans/nix-ai/issues/116)) ([29510d5](https://github.com/JacobPEvans/nix-ai/commit/29510d59c56d0333580797af6a210c92ea1c16b6))
* fix cspell.json word array and pin copilot-setup-steps.yml action SHAs ([#97](https://github.com/JacobPEvans/nix-ai/issues/97)) ([d816596](https://github.com/JacobPEvans/nix-ai/commit/d816596fabe42c6643ba77c68740fc0062ddad53))
* remove blanket auto-merge workflow ([#117](https://github.com/JacobPEvans/nix-ai/issues/117)) ([cc0315b](https://github.com/JacobPEvans/nix-ai/commit/cc0315b19ef3bddd62fae25c6252d010e0cda0eb))
* remove redundant .markdownlint-cli2.yaml ([#91](https://github.com/JacobPEvans/nix-ai/issues/91)) ([6de3e82](https://github.com/JacobPEvans/nix-ai/commit/6de3e8291525ec9f77c79829f48776a2d0aa5e2f))
* rename GH_APP_ID secret to GH_ACTION_JACOBPEVANS_APP_ID ([#132](https://github.com/JacobPEvans/nix-ai/issues/132)) ([ed48910](https://github.com/JacobPEvans/nix-ai/commit/ed4891083564906a6b0fbd87e5302cfbc7e5b5d6))
* resolve MCP server issues and add HuggingFace + MLX tools ([#144](https://github.com/JacobPEvans/nix-ai/issues/144)) ([fe5f2ce](https://github.com/JacobPEvans/nix-ai/commit/fe5f2ce01cbc4859ea4c01f74eeb1c26e81d46c2))
* set cleanupPeriodDays to 30 (upstream default) ([#139](https://github.com/JacobPEvans/nix-ai/issues/139)) ([8c641b6](https://github.com/JacobPEvans/nix-ai/commit/8c641b6d2406b650058a569674d4864d598666ea))
* update gh-aw to v0.57.2 and remove silent failure in workflow ([#135](https://github.com/JacobPEvans/nix-ai/issues/135)) ([c34008d](https://github.com/JacobPEvans/nix-ai/commit/c34008d7cbbe64f22211ab8f17becf89fdc4f944))
* update stale nix-config references to nix-darwin ([#112](https://github.com/JacobPEvans/nix-ai/issues/112)) ([4f09511](https://github.com/JacobPEvans/nix-ai/commit/4f09511c8920851294c76151cc58861caa128363))
* use absolute path for shasum in verify-cache-integrity.sh ([#128](https://github.com/JacobPEvans/nix-ai/issues/128)) ([c8fabcc](https://github.com/JacobPEvans/nix-ai/commit/c8fabcc930dbf5aef22fe16dc9478c82d8c0753d))
