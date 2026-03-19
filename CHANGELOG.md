# Changelog

## [1.16.3](https://github.com/JacobPEvans/nix-ai/compare/v1.16.2...v1.16.3) (2026-03-19)


### Bug Fixes

* auto-sync Claude Code plugin cache after nix rebuild ([#235](https://github.com/JacobPEvans/nix-ai/issues/235)) ([edba1ad](https://github.com/JacobPEvans/nix-ai/commit/edba1adb0d2ade246e7c7ce51a60762d8fb770ae))
* cap Ollama memory at 20G, switch MLX default to Qwen3.5-122B MoE ([#234](https://github.com/JacobPEvans/nix-ai/issues/234)) ([9d82a86](https://github.com/JacobPEvans/nix-ai/commit/9d82a86d8a17b88eeb670e490a6401ff7f92e73f))

## [1.16.2](https://github.com/JacobPEvans/nix-ai/compare/v1.16.1...v1.16.2) (2026-03-19)


### Bug Fixes

* clarify MLX port description as default choice ([#232](https://github.com/JacobPEvans/nix-ai/issues/232)) ([d9125dc](https://github.com/JacobPEvans/nix-ai/commit/d9125dcba9630944fc2258b52aded1e8bf7e5e38))

## [1.16.1](https://github.com/JacobPEvans/nix-ai/compare/v1.16.0...v1.16.1) (2026-03-19)


### Bug Fixes

* change MLX port from 11435 to 11436 (screenpipe conflict) ([#230](https://github.com/JacobPEvans/nix-ai/issues/230)) ([8a8dde9](https://github.com/JacobPEvans/nix-ai/commit/8a8dde9e90ef09491089115fbb19ecaa7856e605))

## [1.16.0](https://github.com/JacobPEvans/nix-ai/compare/v1.15.0...v1.16.0) (2026-03-19)


### Features

* enable MLX inference server (vllm-mlx on port 11435) ([#229](https://github.com/JacobPEvans/nix-ai/issues/229)) ([b7b2a1b](https://github.com/JacobPEvans/nix-ai/commit/b7b2a1b7a977873d4557a6f7e9c8bfece61a213c))


### Bug Fixes

* add release-please config for manifest mode ([5c1d9eb](https://github.com/JacobPEvans/nix-ai/commit/5c1d9ebbab3ec1ef87813e837a188945b74f0e48))
* move sync-ollama-models to pal-models.nix for MLX model append ([#226](https://github.com/JacobPEvans/nix-ai/issues/226)) ([d66fca5](https://github.com/JacobPEvans/nix-ai/commit/d66fca59ee907056e53a23f12ca7853ddfb9b902))
* PAL MCP model routing — fix JSON nesting, MLX-first default, add MLX models ([#225](https://github.com/JacobPEvans/nix-ai/issues/225)) ([15b297a](https://github.com/JacobPEvans/nix-ai/commit/15b297adc5208e54e67056f4382fa3396b525d77))
* **plugins:** update stale plugin count comment in development.nix ([#222](https://github.com/JacobPEvans/nix-ai/issues/222)) ([5ffd43d](https://github.com/JacobPEvans/nix-ai/commit/5ffd43db73206590cda7797aa37a642dc94521c9))
* sync release-please permissions and VERSION ([df6938a](https://github.com/JacobPEvans/nix-ai/commit/df6938a57a3944d5d24bdfdddcfaf2ba5f6d0278))

## [1.15.0](https://github.com/JacobPEvans/nix-ai/compare/v1.14.0...v1.15.0) (2026-03-18)


### Features

* **plugins:** add Bitwarden ai-plugins marketplace ([#217](https://github.com/JacobPEvans/nix-ai/issues/217)) ([f1ddbc1](https://github.com/JacobPEvans/nix-ai/commit/f1ddbc1e639d14fda48546663d21a9eac2f9c5a5))


### Bug Fixes

* **devshell:** use python package attr instead of version in orchestrator shell ([#218](https://github.com/JacobPEvans/nix-ai/issues/218)) ([ae9fe44](https://github.com/JacobPEvans/nix-ai/commit/ae9fe44ff157c664b6f79eb9d3d4b2126d2ef1aa))

## [1.14.0](https://github.com/JacobPEvans/nix-ai/compare/v1.13.0...v1.14.0) (2026-03-18)


### Bug Fixes

* **tests:** use MagicMock instance for SimpleDocumentStore in pipeline tests ([#215](https://github.com/JacobPEvans/nix-ai/issues/215)) ([e788030](https://github.com/JacobPEvans/nix-ai/commit/e788030048a5af2c2ee361250a345cb107da90ad))

## [1.13.0](https://github.com/JacobPEvans/nix-ai/compare/v1.12.0...v1.13.0) (2026-03-17)


### Features

* orchestrator phase 2-3 — loaders, embeddings, workflows ([#208](https://github.com/JacobPEvans/nix-ai/issues/208)) ([585ed75](https://github.com/JacobPEvans/nix-ai/commit/585ed75059233d6a9dff6552efbd8de4b5c83c6e))

## [1.12.0](https://github.com/JacobPEvans/nix-ai/compare/v1.11.0...v1.12.0) (2026-03-17)


### Bug Fixes

* **docs:** correct PAL model script references in MCP README ([#211](https://github.com/JacobPEvans/nix-ai/issues/211)) ([c880929](https://github.com/JacobPEvans/nix-ai/commit/c880929eff3b5cffca4cb6d32e8c9250e4c591ca))

## [1.11.0](https://github.com/JacobPEvans/nix-ai/compare/v1.10.0...v1.11.0) (2026-03-17)


### Bug Fixes

* **plugins:** replace per-file symlinks with directory symlinks ([#186](https://github.com/JacobPEvans/nix-ai/issues/186)) ([cff42d5](https://github.com/JacobPEvans/nix-ai/commit/cff42d58f776b58e75faf8f3a9e45dfa0810b966))

## [1.10.0](https://github.com/JacobPEvans/nix-ai/compare/v1.9.0...v1.10.0) (2026-03-17)


### Features

* add orchestrator devShell with skill schema and semantic router ([de9826d](https://github.com/JacobPEvans/nix-ai/commit/de9826d463f7a950613c6470dbd21e85f9c26754))


### Bug Fixes

* address PR [#188](https://github.com/JacobPEvans/nix-ai/issues/188) review feedback ([a7f4782](https://github.com/JacobPEvans/nix-ai/commit/a7f4782b5e93eb4bc28ff49bf64caf051a90a88d))
* **deps:** update jacobpevans-cc-plugins for /ship command ([#184](https://github.com/JacobPEvans/nix-ai/issues/184)) ([f4983a9](https://github.com/JacobPEvans/nix-ai/commit/f4983a9102065acb942fda376d49f3142ae4b034))
* **devenv:** use python package attr instead of version string ([#187](https://github.com/JacobPEvans/nix-ai/issues/187)) ([daca68a](https://github.com/JacobPEvans/nix-ai/commit/daca68afbf7dc2055853f3fc1c9b19d9b467068b))
* raise issue hard limit from 50 to 150 per repo ([25ccf92](https://github.com/JacobPEvans/nix-ai/commit/25ccf9294a4fc51118acf9de3cb0214e34c5e77f))

## [1.9.0](https://github.com/JacobPEvans/nix-ai/compare/v1.8.0...v1.9.0) (2026-03-15)


### Bug Fixes

* **ci:** add pull-requests:write for release-please auto-approve ([007d630](https://github.com/JacobPEvans/nix-ai/commit/007d630d28ee4b59e2ce11d7926f3f0a0aac2e58))

## [1.8.0](https://github.com/JacobPEvans/nix-ai/compare/v1.7.0...v1.8.0) (2026-03-15)


### Bug Fixes

* **ci:** migrate copilot-setup-steps to determinate-nix-action@v3 ([#175](https://github.com/JacobPEvans/nix-ai/issues/175)) ([47eef4b](https://github.com/JacobPEvans/nix-ai/commit/47eef4b714e6b31e2fdf002d678e824ee247bc72))
* golden standard — bugs, cross-platform, dead code, style ([#174](https://github.com/JacobPEvans/nix-ai/issues/174)) ([4954bd1](https://github.com/JacobPEvans/nix-ai/commit/4954bd1e6a7c6e388dbb26c85736f3cecf8e1ee7))
* migrate Bash permission format from colon to space separator ([#177](https://github.com/JacobPEvans/nix-ai/issues/177)) ([62658c1](https://github.com/JacobPEvans/nix-ai/commit/62658c1ade1cf96e5b735dd0c47c942a3a3dc423))

## [1.7.0](https://github.com/JacobPEvans/nix-ai/compare/v1.6.0...v1.7.0) (2026-03-15)


### Bug Fixes

* **devenv:** use impure eval for runtime DEVENV_ROOT resolution ([#172](https://github.com/JacobPEvans/nix-ai/issues/172)) ([d0247dc](https://github.com/JacobPEvans/nix-ai/commit/d0247dc20ea3a62511e9ea7cbf2c847f2f3778b7))

## [1.6.0](https://github.com/JacobPEvans/nix-ai/compare/v1.5.0...v1.6.0) (2026-03-15)


### Features

* add MLX inference server home-manager module ([#161](https://github.com/JacobPEvans/nix-ai/issues/161)) ([eb4e91f](https://github.com/JacobPEvans/nix-ai/commit/eb4e91ffa3a3a6113e59f57b4b4e5a9529943dc7))
* **devenv:** add nixpkgs-python input and remove flake-level nixConfig ([#170](https://github.com/JacobPEvans/nix-ai/issues/170)) ([b80ceca](https://github.com/JacobPEvans/nix-ai/commit/b80ceca8a6a486877567a339bce8ab30fe57614b))
* migrate flake.lock updates to Renovate nix manager ([#169](https://github.com/JacobPEvans/nix-ai/issues/169)) ([5dbaf23](https://github.com/JacobPEvans/nix-ai/commit/5dbaf23e8bab84847e7ec64a0edf41b9178755ee))


### Bug Fixes

* **ci:** exclude CHANGELOG.md from markdownlint ([#171](https://github.com/JacobPEvans/nix-ai/issues/171)) ([f974ead](https://github.com/JacobPEvans/nix-ai/commit/f974eada87f0c10a29fe6897b5543ebb289b86fd))
* **ci:** upgrade ci-gate.yml to Merge Gatekeeper pattern ([#162](https://github.com/JacobPEvans/nix-ai/issues/162)) ([10a5a47](https://github.com/JacobPEvans/nix-ai/commit/10a5a478b9e57fc870df527838ba686a2315576b))

## [1.5.0](https://github.com/JacobPEvans/nix-ai/compare/v1.4.0...v1.5.0) (2026-03-14)


### Features

* add devenv with ai-dev shell, convert mlx-server to devenv ([#158](https://github.com/JacobPEvans/nix-ai/issues/158)) ([0d1deb1](https://github.com/JacobPEvans/nix-ai/commit/0d1deb113464adb622186e08c4b95d3882db4c8f))

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
