# Claude Code

Claude Code installs hark as a plugin. No manual configuration.

```
/plugin marketplace add sdv0001/hark
/plugin install hark@hark
```

Then `/hark test` to hear it, `/hark list` to see the presets.

## Coverage

| Claude Code event | Role |
|---|---|
| `Stop` | `done` |
| `Notification` | `attention` |
| `PostToolUseFailure` | `error` |
| `SubagentStop` | `subagent` |
| `SessionEnd` | `bye` |

The fullest coverage of the three, which is why the role names read the way
they do.

## Why these files are at the repository root

`.claude-plugin/`, `hooks/` and `commands/` sit at the top level rather than in
this directory. Claude Code's installer expects the plugin manifest at the root
of the source it is given, and `${CLAUDE_PLUGIN_ROOT}` then resolves to that
root — which is where `scripts/` lives. Moving them under `integrations/` would
mean the hooks reaching back out with `../../`, on a path that only breaks once
it is on someone else's machine.

The other agents are configured by hand from a snippet, so they have no such
constraint and live here.

## Checking it works

`/hark test` plays every role of the active preset and prints the file each one
maps to. If Claude Code was already running when you installed, open `/hooks`
once — that reloads the hook configuration.
