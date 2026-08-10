# Codex

Codex has a `notify` setting: one external program, called for every
notification, with the payload as a single JSON argument.

## Setup

Add to `~/.codex/config.toml`:

```toml
notify = ["/bin/sh", "/absolute/path/to/hark/scripts/hark.sh", "codex"]
```

Codex appends the payload, so the program actually runs as:

```sh
sh /absolute/path/to/hark/scripts/hark.sh codex '{"type":"agent-turn-complete",...}'
```

Use an absolute path — `notify` is not resolved against your shell's `PATH`
or your current directory.

On Windows, point it at the PowerShell twin instead:

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
