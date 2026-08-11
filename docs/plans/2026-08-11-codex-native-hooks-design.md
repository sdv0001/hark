# Native Codex Hooks Design

**Date:** 2026-08-11  
**Status:** Approved

## Goal

Replace hark's legacy Codex `notify` integration with the native plugin and
hook contract available in Codex 0.147 and later. At the same time, simplify
the runtime, fix known configuration and playback defects, and make the
repository's tests, documentation, and metadata describe the behavior that is
actually supported.

## Constraints

- No runtime dependency on Node.js, Python, `jq`, or another JSON parser.
- The notification path must never be able to fail an agent session.
- The POSIX and PowerShell entry points must keep the same roles and config
  precedence.
- Codex and Claude Code must use only properties documented by their native
  hook implementations.
- Existing Gemini CLI behavior remains supported.

## Selected Architecture

The repository will expose two small hook contracts over one shared audio
core:

- `hooks/hooks.json` is the default-discovered Codex hook file.
- `.codex-plugin/plugin.json` is a minimal Codex plugin manifest. It does not
  declare a custom hooks path because Codex discovers `hooks/hooks.json`.
- `hooks/claude.json` contains Claude Code-specific events and is referenced
  by `.claude-plugin/plugin.json`.
- `scripts/hark.sh` and `scripts/hark.ps1` remain the only playback engines.

This split avoids a misleading superset file: Codex and Claude Code expose
different events and support different command properties. A universal
dispatcher was rejected because it would add a runtime dependency or a large
cross-shell compatibility layer without improving the audio core.

## Hook Behavior

Codex 0.147+ maps native events as follows:

| Codex event | hark role |
|---|---|
| `Stop` | `done` |
| `PermissionRequest` | `attention` |
| `SubagentStop` | `subagent` |
| `SessionEnd` | `bye` |

Codex has no native event in the selected contract that reliably means
"agent error", so hark will not manufacture an `error` notification from a
different event. POSIX commands will return immediately by launching playback
in the background. Windows commands will use Codex's documented
`commandWindows` path and PowerShell.

Claude Code keeps the richer mapping:

| Claude Code event | hark role |
|---|---|
| `Stop` | `done` |
| `PermissionRequest` | `attention` |
| `PostToolUseFailure` and `StopFailure` | `error` |
| `SubagentStop` | `subagent` |
| `SessionEnd` | `bye` |

The broad `Notification` event is replaced by `PermissionRequest` so unrelated
notifications do not trigger attention sounds. Claude commands use documented
`async` behavior. On Windows, the dependency-free Claude path uses Git Bash,
which is the shell Claude Code selects when Git for Windows is available.
Direct PowerShell playback remains supported and Codex uses its native Windows
command override.

## Legacy Removal

The following Codex-only compatibility path will be deleted completely:

- the `codex <json>` subcommand in both runtime scripts;
- substring matching of Codex JSON payloads;
- the `install codex` command and all writes to `~/.codex/config.toml`;
- tests, examples, changelog entries, and troubleshooting text for `notify`;
- warnings that Codex plugins cannot carry hooks.

No migration shim will remain. Documentation will tell existing users to
remove their old `notify` entry before installing the plugin.

## Runtime Corrections

The POSIX implementation will be corrected without adding abstractions:

- preserve environment overrides for every `HARK_SOUND_*` setting, not only
  preset, volume, and player;
- process a final config line even when it has no trailing newline;
- normalize volume as decimal text before arithmetic so values such as `08`
  are safe and very large inputs cannot overflow shell tests;
- invoke the resolved `HARK_PLAYER` path rather than a hard-coded executable
  name for suffix-matched players;
- replace per-line `tr` and `sed` processes with POSIX parameter expansion.

The PowerShell fallback launched from POSIX will pass the sound path through
an environment variable instead of interpolating it into PowerShell source.
This keeps spaces and quotes in paths out of executable code.

## Validation Strategy

Implementation follows red-green-refactor:

1. Add regression tests for environment/config precedence, unterminated config
   files, numeric volume edge cases, explicit player paths, and safe
   PowerShell fallback arguments.
2. Add standard-library metadata tests for both manifests and both hook files,
   including event-to-role mappings and absence of the legacy `notify` path.
3. Confirm the new tests fail for the expected reasons.
4. Apply the smallest runtime and metadata changes that make them pass.
5. Run POSIX tests under the available shells, PowerShell tests where
   available, manifest validation, shell syntax checks, and the complete CI
   command set.

## Documentation and Release Hygiene

The README, integration guides, contributor guide, changelog, marketplace
metadata, and CI configuration will be aligned with the native plugin flow.
Codex installation will use the marketplace/plugin workflow for 0.147+ and
will include a concise migration note for deleting the old `notify` key.

The change prepares the next minor release but does not create tags, publish a
marketplace release, or modify external state.
