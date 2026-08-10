# claude-chime

[![CI](https://github.com/sdv0001/claude-chime/actions/workflows/ci.yml/badge.svg)](https://github.com/sdv0001/claude-chime/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Claude Code finishes. You are in another window. You find out four minutes later.**

claude-chime plays a short sound the moment Claude finishes a turn, needs your
attention, or hits an error — so you can go read something else and come back
when it actually matters.

No dependencies. No `jq`, no Node, no Python at runtime. It is a shell script
and ten small WAV files.

## Install

```
/plugin marketplace add sdv0001/claude-chime
/plugin install claude-chime@claude-chime
```

That is it — the hooks register themselves. Hear it right now with `/chime test`.

> Already wired sounds by hand in `settings.json`? Remove those hooks after
> installing, or you will hear everything twice.

## When it fires

| Event | You hear it when | Role |
|---|---|---|
| `Stop` | Claude finished its turn | `done` |
| `Notification` | Claude is waiting on you — a permission prompt, or an idle question | `attention` |
| `PostToolUseFailure` | a tool call failed | `error` |
| `SubagentStop` | a background agent finished | `subagent` |
| `SessionEnd` | the session closed | `bye` |

## Presets

Switch with `/chime set <name>`, or by writing `CHIME_PRESET` into the config.

| Preset | What it is |
|---|---|
| `default` | The bundled chime set. Identical on every OS. |
| `subtle` | The same sounds, quieter and shorter. For open offices and late nights. |
| `macos` | macOS system sounds — Glass, Funk, Basso, Tink. Silent on other platforms. |
| `minimal` | Only `done` and `attention`. Errors and subagents stay quiet. |
| `off` | Silence, without uninstalling. |

## Configuration

`~/.claude/chime.conf`, plain `KEY=value`. Environment variables override it.

```sh
CHIME_PRESET=subtle
CHIME_VOLUME=40
# Use your own sound for just one event:
CHIME_SOUND_ATTENTION=/Users/me/sounds/hey.wav
```

| Key | Values | Notes |
|---|---|---|
| `CHIME_PRESET` | `default` `subtle` `macos` `minimal` `off` | Unknown values fall back to `default` |
| `CHIME_VOLUME` | `0`–`100` | Ignored by `aplay` and PowerShell, which have no volume control |
| `CHIME_PLAYER` | a command name | Force a player instead of auto-detecting |
| `CHIME_SOUND_<ROLE>` | a file path | Override one role: `DONE`, `ATTENTION`, `ERROR`, `SUBAGENT`, `BYE` |

The config file is **parsed, never sourced** — it lives in a directory several
tools write to, and a settings file has no business executing code. Keys that
are not on the list above are ignored.

Prefer to configure it in conversation? `/chime list`, `/chime set subtle`,
`/chime volume 30`, `/chime status`, `/chime off`.

## Platform support

| OS | Player | Volume | Tested in CI |
|---|---|---|---|
| macOS | `afplay` | yes | yes |
| Linux | `paplay` → `aplay` → `ffplay` → `play` | except `aplay` | yes |
| Windows | `Media.SoundPlayer` via `scripts/chime.ps1` | no | yes |

First player found wins. If none is found, nothing happens and the session
continues — see below.

## How it works

Three moving parts, worth knowing before you let a stranger's plugin run on
every turn:

1. `hooks/hooks.json` binds five Claude Code events to `scripts/chime.sh <role>`.
2. `scripts/chime.sh` maps `(preset, role)` to a file and hands it to an audio
   player. The hook payload arrives on stdin as JSON and is **ignored** — the
   role comes in as an argument, which is why no JSON parser is needed.
3. The script **exits 0 on every path**, including when the file is missing,
   the player is absent, or the config is malformed. A notifier that can break
   your session is worse than no notifier.

Hooks are marked `async`, so playback never blocks Claude.

## The sounds

Generated, not sampled: `tools/gen_sounds.py` writes them from sine waves using
only the Python standard library. Run it to regenerate, edit `VOICES` to
recompose. They are WAV because WAV is the one format every player above reads.

This also means the audio in this repo is unambiguously ours to license, with
no sample-pack attribution to trace.

## Turning it off

`/chime off` — or `CHIME_PRESET=off` — silences everything while keeping the
plugin installed. To remove it entirely: `/plugin uninstall claude-chime`.

## Contributing

Bug reports and new presets are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
Tests run with `sh tests/test.sh` and need no audio device.

## License

MIT — see [LICENSE](LICENSE).
