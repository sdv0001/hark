# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Native Codex 0.147+ plugin manifest and hooks for turn completion, permission
  requests, subagent completion and session end.
- Contract tests for Codex and Claude plugin metadata and event mappings.

### Changed
- Codex and Claude Code now use separate native hook contracts over the same
  playback core.
- Claude Code attention sounds use `PermissionRequest` instead of every
  `Notification`; `StopFailure` now maps to `error`.

### Removed
- The legacy Codex payload parser and `install codex` configuration writer from
  both runtime entry points.

### Fixed
- Environment sound overrides now take precedence over config-file values.
- POSIX config parsing accepts a final line without a newline and no longer
  starts `tr` and `sed` for every setting.
- Leading-zero and oversized volume values no longer reach unsafe arithmetic.
- Absolute `HARK_PLAYER` paths are respected for recognized players.
- PowerShell fallback paths are transported as data instead of interpolated
  into executable source.
- `/hark status` now reports environment overrides and Windows players.

## [0.1.0] - 2026-08-10

First release.

### Added
- An agent-neutral core: `scripts/hark.sh <role>`, where role is one of
  `done`, `attention`, `error`, `subagent`, `bye`.
- Claude Code integration as an installable plugin, covering all five roles.
- Initial Codex sound integration for `done` and `attention`.
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
