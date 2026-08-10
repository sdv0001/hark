---
description: Configure claude-chime — list or switch presets, set volume, test the sounds, or go silent.
argument-hint: "[list | set <preset> | volume <0-100> | test | off | status]"
allowed-tools: Bash, Read, Write, Edit
---

# /chime

Configure the sound notifications played by claude-chime.

Config lives in `~/.claude/chime.conf`, a plain `KEY=value` file. Create it if
it does not exist. Only these keys are read; anything else is ignored:

| Key | Values | Meaning |
|-----|--------|---------|
| `CHIME_PRESET` | `default`, `subtle`, `macos`, `minimal`, `off` | Which sound set to use |
| `CHIME_VOLUME` | `0`-`100` | Playback volume (ignored by `aplay` and PowerShell) |
| `CHIME_PLAYER` | a command name | Force a specific audio player |
| `CHIME_SOUND_DONE` | a file path | Override just the "finished" sound |
| `CHIME_SOUND_ATTENTION` | a file path | Override just the "needs you" sound |
| `CHIME_SOUND_ERROR` | a file path | Override just the "tool failed" sound |
| `CHIME_SOUND_SUBAGENT` | a file path | Override just the "subagent done" sound |
| `CHIME_SOUND_BYE` | a file path | Override just the "session ended" sound |

## What the user asked for

`$ARGUMENTS`

## How to handle it

**`list`** or no argument — show the presets and mark the active one. Read
`~/.claude/chime.conf` first to know which it is; absent file means `default`.

- `default` — the bundled chime set. Same on every OS.
- `subtle` — the same sounds, quieter and shorter.
- `macos` — macOS system sounds (Glass, Funk, Basso, Tink). Silent elsewhere.
- `minimal` — only "finished" and "needs you". Errors and subagents stay quiet.
- `off` — silence, without uninstalling the plugin.

**`set <preset>`** — write `CHIME_PRESET=<preset>` to the config, preserving
any other keys already in the file. Reject a preset that is not in the list
above. Then play the new "done" sound so the user hears the change:
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/chime.sh" done`

**`volume <0-100>`** — write `CHIME_VOLUME=<n>`, same preserving rules, then
play the "done" sound at the new volume.

**`test`** — run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/chime.sh" test`. It plays
every role of the active preset in order and prints which file each maps to.

**`off`** — write `CHIME_PRESET=off`. Mention that `/chime set default` brings
the sounds back, and that this is preferable to uninstalling if they only want
quiet for a while.

**`status`** — show the active preset, volume, any per-role overrides, and
which audio player would actually be used on this machine. Detect the player
with: `for p in afplay paplay aplay ffplay play; do command -v $p && break; done`

## Rules

- Never rewrite the whole config file from scratch — read it, change the one
  key, keep the rest. Users put comments in there.
- On Windows use `scripts/chime.ps1` instead of `scripts/chime.sh`.
- If the user asks for something not covered above, say what `/chime` supports
  rather than inventing a key. The script ignores unrecognised keys silently,
  so an invented one fails quietly and confusingly.
