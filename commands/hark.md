---
description: Configure hark — list or switch presets, set volume, test the sounds, or go silent.
argument-hint: "[list | set <preset> | volume <0-100> | test | off | status]"
allowed-tools: Bash, Read, Write, Edit
---

# /hark

Configure the sound notifications played by hark.

Config lives at `$XDG_CONFIG_HOME/hark/config`, falling back to
`~/.config/hark/config`. It is a plain `KEY=value` file — create it, and its
parent directory, if absent. Only these keys are read; anything else is ignored:

| Key | Values | Meaning |
|-----|--------|---------|
| `HARK_PRESET` | `default`, `subtle`, `macos`, `minimal`, `off` | Which sound set to use |
| `HARK_VOLUME` | `0`-`100` | Playback volume (ignored by `aplay` and PowerShell) |
| `HARK_PLAYER` | a command name or path | Force a specific audio player |
| `HARK_SOUND_DONE` | a file path | Override just the "finished" sound |
| `HARK_SOUND_ATTENTION` | a file path | Override just the "needs you" sound |
| `HARK_SOUND_ERROR` | a file path | Override just the "tool failed" sound |
| `HARK_SOUND_SUBAGENT` | a file path | Override just the "subagent done" sound |
| `HARK_SOUND_BYE` | a file path | Override just the "session ended" sound |

The config is shared by every agent hark is wired into, so a change here also
changes what Codex and Gemini CLI sound like on this machine. Say so if the
user seems to expect a per-agent setting.

## What the user asked for

`$ARGUMENTS`

## How to handle it

**`list`** or no argument — show the presets and mark the active one. Read the
config file first to know which it is; absent file means `default`.

- `default` — the bundled sound set. Same on every OS.
- `subtle` — the same sounds, quieter and shorter.
- `macos` — macOS system sounds (Glass, Funk, Basso, Tink). Silent elsewhere.
- `minimal` — only "finished" and "needs you". Errors and subagents stay quiet.
- `off` — silence, without uninstalling the plugin.

**`set <preset>`** — write `HARK_PRESET=<preset>` to the config, preserving any
other keys already in the file. Reject a preset that is not in the list above.
Then play the new "done" sound so the user hears the change:
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/hark.sh" done`

**`volume <0-100>`** — write `HARK_VOLUME=<n>`, same preserving rules, then play
the "done" sound at the new volume.

**`test`** — run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/hark.sh" test`. It plays
every role of the active preset in order and prints which file each maps to.

**`off`** — write `HARK_PRESET=off`. Mention that `/hark set default` brings the
sounds back, and that this is preferable to uninstalling if they only want quiet
for a while.

**`status`** — show the active preset, volume, any per-role overrides, and which
audio player would actually be used on this machine. Environment variables
override the config file and must be reflected in the result. Respect
`HARK_PLAYER` first; otherwise detect with:
`for p in afplay paplay aplay ffplay play powershell.exe pwsh; do command -v "$p" && break; done`

## Rules

- Never rewrite the whole config file from scratch — read it, change the one
  key, keep the rest. Users put comments in there.
- On Windows use `scripts/hark.ps1` instead of `scripts/hark.sh`.
- If the user asks for something not covered above, say what `/hark` supports
  rather than inventing a key. The script ignores unrecognised keys silently, so
  an invented one fails quietly and confusingly.
