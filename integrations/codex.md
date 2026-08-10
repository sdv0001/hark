# Codex

Codex has a `notify` setting: one external program, called for every
notification, with the payload as a single JSON argument.

## Setup

```sh
git clone https://github.com/sdv0001/hark.git ~/.hark
sh ~/.hark/scripts/hark.sh install codex
```

Clone it somewhere it will stay: `notify` records an absolute path, and moving
or deleting the checkout later leaves Codex pointing at nothing. `~/.hark` is a
suggestion, any permanent path works, and the installer records wherever it is
run from.

You run this once per machine, not once per project. `~/.codex/config.toml` is
Codex's global config and `notify` is a top-level key in it, so it applies to
every session in every directory. There is no per-project variant to set up.

It writes the line below into `~/.codex/config.toml` (or `$CODEX_HOME`),
filling in this checkout's absolute path. It backs the file up to
`config.toml.bak` first, and if the file already sets `notify` — yours or
another tool's — it changes nothing and prints the line for you to merge by
hand: Codex runs one notify program, and a second `notify` key is a TOML
duplicate that would make Codex reject the whole file.

By hand, the same thing:

```toml
notify = ["/bin/sh", "/absolute/path/to/hark/scripts/hark.sh", "codex"]
```

Put it above the first `[section]` header. `notify` is a top-level key, and a
line appended to the end of the file belongs to whatever section precedes it —
Codex reads it as `[that-section].notify`, which is not an error and not a
notifier either. It just never makes a sound.

## Why not install it as a Codex plugin

Because it would look like it worked and then stay silent.

Codex 0.147 has a plugin system, and it accepts this repository: hark ships a
Claude Code marketplace manifest, and Codex reads that format. Both of these
succeed, print success, and leave you with `installed, enabled`:

```sh
codex plugin marketplace add sdv0001/hark   # Added marketplace `hark`.
codex plugin add hark@hark                  # Added plugin `hark`.
```

No sound ever plays. Plugins in Codex cannot contribute hooks:

```
$ codex features list | grep plugin_hooks
plugin_hooks    removed    false
```

Verified against 0.147.0, not inferred: with `notify` disabled and the audio
player replaced by a logger, a full turn through a plugin carrying both a
`.codex-plugin/plugin.json` and a root `hooks.json` fired nothing at all.

So `notify` is not a workaround here, it is the mechanism Codex offers. If
`plugin_hooks` comes back, this integration gets shorter and gains the roles
`notify` cannot express — that is the day to revisit it.

Codex appends the payload, so the program actually runs as:

```sh
sh /absolute/path/to/hark/scripts/hark.sh codex '{"type":"agent-turn-complete",...}'
```

Use an absolute path — `notify` is not resolved against your shell's `PATH`
or your current directory.

On Windows there is no installer yet — `install` lives in `hark.sh` only. Point
`notify` at the PowerShell twin by hand:

```toml
notify = ["powershell", "-NoProfile", "-File", "C:\\path\\to\\hark\\scripts\\hark.ps1", "codex"]
```

PowerShell's `-File` parsing strips the double quotes out of the payload
argument, so hark matches the event type with quotes removed. Both the quoted
and unquoted forms work, and CI covers both.

## Coverage

| Codex event | Role |
|---|---|
| `agent-turn-complete` | `done` |
| `approval-requested` | `attention` |
| anything else | silent |

Codex emits no tool-failure, subagent or session-end notification, so `error`,
`subagent` and `bye` never fire here. If that changes, the mapping lives in
`codex_role()` in `scripts/hark.sh` and is about ten lines.

## How the event is read

Codex is the one agent that hands over its event type inside JSON rather than
letting the config name a role per event. hark matches the `type` field as a
substring instead of taking on a JSON parser for one field — see the note above
`codex_role()`. The known limitation: a payload whose free-text message quotes
one of those type strings verbatim would be misread.

## Checking it works

```sh
sh scripts/hark.sh codex '{"type":"agent-turn-complete"}'
```

Should play the "done" sound. If it is silent, run `sh scripts/hark.sh test` —
that prints the resolution table and will show whether the problem is the
mapping or the sound files.
