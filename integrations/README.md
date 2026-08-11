# Integrations

hark's core knows nothing about any agent. It is a command:

```sh
scripts/hark.sh <role>
```

where `<role>` is one of `done`, `attention`, `error`, `subagent`, `bye`.

An integration is therefore very small: whatever your agent does when something
happens, make it run that command with the right role. Everything else —
presets, volume, per-role overrides, player detection — is already handled.

## The roles

| Role | Means |
|---|---|
| `done` | The agent finished its turn and it is your move |
| `attention` | The agent is blocked on you: a permission prompt, a question |
| `error` | A tool call failed |
| `subagent` | A background or child agent finished |
| `bye` | The session ended |

An agent that has no equivalent of a role simply never triggers it. That is
expected — see the coverage table in the top-level README. Do not invent a
mapping to fill a gap; a sound that fires at the wrong moment is worse than
silence, because the user stops trusting all of them.

## Supported today

- [Claude Code](claude-code.md) — installs as a plugin, no manual config
- [Codex 0.147+](codex.md) — installs as a plugin, no manual config
- [Gemini CLI](gemini.md) — a `hooks` block in `settings.json`

## Wiring up an agent that is not listed

If it can run a shell command on an event, it can use hark. You need two things:

1. **Where it configures event commands.** A hooks file or plugin manifest.
2. **Which events honestly map to hark's roles.** Point each event at
   `hark.sh <role>` and ignore the payload. This is the same model used by all
   three supported integrations and keeps the audio core agent-neutral.

Contributions adding an agent are welcome. Please include the version you
tested against and a link to that agent's hook documentation, so the next
person can tell when the format has moved on. See [CONTRIBUTING.md](../CONTRIBUTING.md).
