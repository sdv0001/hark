# Gemini CLI

Gemini CLI has a hooks system configured in `settings.json`, shaped almost
identically to Claude Code's — with one difference that will bite you:
**`timeout` is in milliseconds here**, not seconds.

## Setup

Merge into `~/.gemini/settings.json` (or `.gemini/settings.json` in a project,
if you only want it there):

```json
{
  "hooks": {
    "AfterAgent": [
      {
        "hooks": [
          {
            "type": "command",
            "name": "hark: done",
            "command": "sh /absolute/path/to/hark/scripts/hark.sh done",
            "timeout": 10000
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "name": "hark: attention",
            "command": "sh /absolute/path/to/hark/scripts/hark.sh attention",
            "timeout": 10000
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "name": "hark: bye",
            "command": "sh /absolute/path/to/hark/scripts/hark.sh bye",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

If you already have a `hooks` block, add these entries to it rather than
replacing it.

## Coverage

| Gemini CLI event | Role |
|---|---|
| `AfterAgent` | `done` |
| `Notification` | `attention` |
| `SessionEnd` | `bye` |
| — | `error` never fires |
| — | `subagent` never fires |

Gemini CLI's `AfterTool` does not distinguish a failed call from a successful
one, and there is no subagent-completion event, so those two roles stay silent
rather than being faked from something that does not mean the same thing.

## Checking it works

```sh
sh /absolute/path/to/hark/scripts/hark.sh done
```

If that plays and the hook does not, the problem is the settings file, not
hark: check that `hooks` merged correctly and that the hooks system is enabled.
