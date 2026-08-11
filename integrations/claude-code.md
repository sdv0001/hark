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
| `PermissionRequest` | `attention` |
| `PostToolUseFailure`, `StopFailure` | `error` |
| `SubagentStop` | `subagent` |
| `SessionEnd` | `bye` |

The fullest coverage of the three, which is why the role names read the way
they do.

Claude Code's broad `Notification` event is deliberately not used: it also
covers informational messages that do not require the user. `PermissionRequest`
is the precise “needs you” signal.

On Windows, the dependency-free hook command uses Git Bash, which Claude Code
selects when Git for Windows is installed. The PowerShell entry point remains
available for direct use; Codex uses it through its native Windows override.

## Why these files are at the repository root

`.claude-plugin/`, `hooks/` and `commands/` sit at the top level rather than in
this directory. Claude Code's manifest selects `hooks/claude.json`, and
`${CLAUDE_PLUGIN_ROOT}` resolves to the plugin root — which is where `scripts/`
lives. Codex separately discovers `hooks/hooks.json` from that same root.

Gemini CLI is configured by hand from a snippet, so its guide has no such
filesystem constraint and lives under `integrations/`.

## Checking it works

`/hark test` plays every role of the active preset and prints the file each one
maps to. If Claude Code was already running when you installed, open `/hooks`
once — that reloads the hook configuration.
