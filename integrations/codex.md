# Codex 0.147+

hark is a native Codex plugin. Codex discovers `hooks/hooks.json`, exposes the
installed directory as `${PLUGIN_ROOT}`, and runs one dependency-free command
for each mapped event.

## Setup

```sh
codex plugin marketplace add sdv0001/hark
codex plugin add hark@hark
```

Restart Codex after installation. Open `/hooks` to inspect the four commands
and approve them if Codex asks you to trust hooks from the new plugin.

The minimum supported version is Codex 0.147. Earlier versions used a different
integration path and are intentionally unsupported.

## Migrating from the old integration

If you previously installed hark through Codex's global notifier, remove the
top-level hark `notify = [...]` entry from `~/.codex/config.toml`. Do not remove
another tool's notifier. The native plugin does not need or read this setting.

There is no migration command: removing one obsolete line is safer than letting
a sound plugin rewrite a user's global Codex configuration.

## Coverage

| Codex event | Role |
|---|---|
| `Stop` | `done` |
| `PermissionRequest` | `attention` |
| `SubagentStop` | `subagent` |
| `SessionEnd` | `bye` |
| — | `error` remains silent |

Codex 0.147 has no supported hook in this contract that reliably means “the
agent failed”. hark leaves `error` silent rather than attaching it to an event
that only approximately means failure.

## Platform behavior

On macOS and Linux, each hook starts `scripts/hark.sh` in the background. On
Windows, Codex's documented `commandWindows` override starts
`scripts/hark.ps1` in a hidden PowerShell process. Both paths resolve the same
roles, presets, and shared config without parsing the hook payload.

## Checking it works

1. Run `codex plugin list` and confirm `hark@hark` is installed and enabled.
2. Open `/hooks` and confirm the four hark hooks are present and trusted.
3. Run `sh scripts/hark.sh test` from a checkout to verify sound resolution, or
   set `HARK_PRESET=off` temporarily if you only need to test hook loading.

If direct playback works but hooks do not appear, upgrade to Codex 0.147 or
later and refresh the marketplace snapshot before reinstalling the plugin.
