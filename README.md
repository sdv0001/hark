# hark

[![CI](https://github.com/sdv0001/hark/actions/workflows/ci.yml/badge.svg)](https://github.com/sdv0001/hark/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Your agent finished. You are in another window. You find out four minutes later.**

hark plays a short sound the moment a coding agent finishes a turn, needs your
attention, or hits an error — so you can go read something else and come back
when it actually matters.

Works with **Claude Code**, **Codex** and **Gemini CLI**, from one config and
one set of sounds. Nothing in the core is tied to any of them.

No dependencies. No `jq`, no Node, no Python at runtime. It is a shell script
and ten small WAV files.

## Install

**Claude Code** — installs as a plugin, no manual config:

```
/plugin marketplace add sdv0001/hark
/plugin install hark@hark
```

**Codex** — one line in `~/.codex/config.toml`:

```toml
notify = ["/bin/sh", "/absolute/path/to/hark/scripts/hark.sh", "codex"]
```

**Gemini CLI** — a `hooks` block in `settings.json`: see
[integrations/gemini.md](integrations/gemini.md).

**Anything else** — if it can run a command on an event, it can use hark:
[integrations/README.md](integrations/README.md).

## What you hear, and when

hark has five roles. Each agent maps its own events onto them, and covers as
many as it actually emits:

| Role | Means | Claude Code | Codex | Gemini CLI |
|---|---|:--:|:--:|:--:|
| `done` | Finished its turn, your move | ✅ | ✅ | ✅ |
| `attention` | Blocked on you — a prompt, a question | ✅ | ✅ | ✅ |
| `error` | A tool call failed | ✅ | — | — |
| `subagent` | A background agent finished | ✅ | — | — |
| `bye` | Session ended | ✅ | — | ✅ |

A dash means that agent emits no event that honestly means this. Those roles
stay silent there rather than being wired to something that nearly means it —
a sound that fires at the wrong moment costs you trust in all of them.

## Presets

| Preset | What it is |
|---|---|
| `default` | The bundled sound set. Identical on every OS. |
| `subtle` | The same sounds, quieter and shorter. For open offices and late nights. |
| `macos` | macOS system sounds — Glass, Funk, Basso, Tink. Silent on other platforms. |
| `minimal` | Only `done` and `attention`. Errors and subagents stay quiet. |
| `off` | Silence, without uninstalling. |

In Claude Code, switch with `/hark set subtle`. Anywhere else, edit the config.

## Configuration

One file for every agent: `$XDG_CONFIG_HOME/hark/config`, or
`~/.config/hark/config`. Plain `KEY=value`. Environment variables override it.

```sh
HARK_PRESET=subtle
HARK_VOLUME=40
# Use your own sound for just one event:
HARK_SOUND_ATTENTION=/home/me/sounds/hey.wav
```

| Key | Values | Notes |
|---|---|---|
| `HARK_PRESET` | `default` `subtle` `macos` `minimal` `off` | Unknown values fall back to `default` |
| `HARK_VOLUME` | `0`–`100` | Ignored by `aplay` and PowerShell, which have no volume control |
| `HARK_PLAYER` | a command name | Force a player instead of auto-detecting |
| `HARK_SOUND_<ROLE>` | a file path | Override one role: `DONE`, `ATTENTION`, `ERROR`, `SUBAGENT`, `BYE` |

The config file is **parsed against an allowlist, never sourced**. A settings
file has no business executing code, and both test suites keep a canary test to
make sure it stays that way.

## Platform support

| OS | Player | Volume | Tested in CI |
|---|---|---|---|
| macOS | `afplay` | yes | yes |
| Linux | `paplay` → `aplay` → `ffplay` → `play` | except `aplay` | yes |
| Windows | `Media.SoundPlayer` via `scripts/hark.ps1` | no | yes |

First player found wins. If none is found, nothing happens and your session
continues.

## How it works

Worth knowing before you let a stranger's script run on every turn:

1. Your agent's integration runs `scripts/hark.sh <role>`.
2. That script maps `(preset, role)` to a file and hands it to an audio player.
   Hook payloads arriving on stdin are **ignored** — the role comes in as an
   argument, which is why no JSON parser is needed. (Codex is the exception: it
   passes its event type as JSON in argv, and gets a ten-line substring match
   rather than a parser.)
3. The script **exits 0 on every path**, including when the file is missing, the
   player is absent, or the config is malformed. A notifier that can break your
   session is worse than no notifier.

Playback never blocks the agent.

## The sounds

Generated, not sampled: `tools/gen_sounds.py` writes them from sine waves using
only the Python standard library. Run it to regenerate, edit `VOICES` to
recompose. They are WAV because WAV is the one format every player above reads.

This also means the audio here is unambiguously ours to license, with no
sample-pack attribution to trace.

## Turning it off

`HARK_PRESET=off` silences everything while leaving the wiring in place — in
Claude Code, `/hark off`. To remove it entirely, uninstall the plugin or delete
the lines you added to your agent's config.

## Contributing

Adding an agent is the most useful thing you can contribute, and it is usually
a documentation file plus a table row. See [CONTRIBUTING.md](CONTRIBUTING.md).
Tests run with `sh tests/test.sh` and need no audio device.

## Prior art

[Stovoy/codex-notify-chime](https://github.com/Stovoy/codex-notify-chime) does
this for Codex alone. If Codex is all you use, it is a smaller thing to install.

## License

MIT — see [LICENSE](LICENSE).
