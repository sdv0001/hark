# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-08-10

First release.

### Added
- Sound notifications for five Claude Code events: `Stop`, `Notification`,
  `PostToolUseFailure`, `SubagentStop`, `SessionEnd`.
- Five presets: `default`, `subtle`, `macos`, `minimal`, `off`.
- Ten bundled WAV sounds, generated from sine waves by `tools/gen_sounds.py`.
- Configuration via `~/.claude/chime.conf` and environment variables, including
  per-role sound overrides and a 0-100 volume knob.
- `/chime` slash command for listing, switching, testing and silencing.
- Windows support through `scripts/chime.ps1`, exercised on a Windows CI runner.
- Self-check suites for both shells that need no audio device.

[Unreleased]: https://github.com/sdv0001/claude-chime/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sdv0001/claude-chime/releases/tag/v0.1.0
