# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `hark.sh install codex`, which writes the `notify` line into
  `~/.codex/config.toml` with the absolute path filled in. It prepends the
  key, because appended below a `[section]` header TOML reads it as part of
  that section and Codex stays silent. An existing `notify` is never
  overwritten. Not available in `hark.ps1` yet.

### Changed
- The Codex install instructions start from a clone at a stable path and say
  that `notify` is global, so it is clear there is nothing to repeat per
  project.
- `integrations/codex.md` documents why hark cannot be installed as a Codex
  plugin: Codex accepts the Claude Code manifest and reports success, but
  `plugin_hooks` is a removed feature in 0.147, so no hook ever runs.

## [0.1.0] - 2026-08-10

First release.

### Added
- An agent-neutral core: `scripts/hark.sh <role>`, where role is one of
  `done`, `attention`, `error`, `subagent`, `bye`.
- Claude Code integration as an installable plugin, covering all five roles.
- Codex integration through the `notify` program, covering `done` and
  `attention`. Its JSON payload is matched as a substring rather than parsed,
  so the runtime stays dependency-free.
- Gemini CLI integration through `settings.json` hooks, covering `done`,
  `attention` and `bye`.
- Five presets: `default`, `subtle`, `macos`, `minimal`, `off`.
- Ten bundled WAV sounds, generated from sine waves by `tools/gen_sounds.py`.
- One shared config at `$XDG_CONFIG_HOME/hark/config`, with per-role sound
  overrides and a 0-100 volume knob. Parsed against an allowlist, never sourced.
- `/hark` slash command for Claude Code: list, set, volume, test, off, status.
- Windows support through `scripts/hark.ps1`, exercised on a Windows CI runner.
- Self-check suites for both shells that need no audio device.

[Unreleased]: https://github.com/sdv0001/hark/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sdv0001/hark/releases/tag/v0.1.0
