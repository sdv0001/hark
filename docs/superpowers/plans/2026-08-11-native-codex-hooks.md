# Native Codex Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the legacy Codex `notify` path and ship a dependency-free, native Codex 0.147+ plugin with correct hooks, hardened playback, and aligned documentation.

**Architecture:** Codex owns the default `hooks/hooks.json` contract and a minimal `.codex-plugin/plugin.json`; Claude Code points to a separate `hooks/claude.json`. Both integrations call the existing POSIX or PowerShell role-based playback engines, which remain agent-neutral.

**Tech Stack:** POSIX `sh`, Windows PowerShell 5.1, JSON plugin manifests, Python standard-library contract tests, GitHub Actions.

## Global Constraints

- Support Codex 0.147 and later through native plugins and hooks only.
- Delete the Codex `notify` parser, installer, tests, and documentation completely.
- Add no runtime dependency on Node.js, Python, `jq`, or another JSON parser.
- Notification failures must never fail an agent session.
- Preserve the five public roles: `done`, `attention`, `error`, `subagent`, `bye`.
- Preserve Gemini CLI behavior.
- Use only documented hook properties for each host.

---

### Task 1: Native plugin and hook contracts

**Files:**
- Create: `.codex-plugin/plugin.json`
- Create: `hooks/claude.json`
- Modify: `hooks/hooks.json`
- Modify: `.claude-plugin/plugin.json`
- Create: `tests/test_metadata.py`

**Interfaces:**
- Consumes: `scripts/hark.sh <role>` and `scripts/hark.ps1 <role>`.
- Produces: Codex default hook discovery and a Claude-specific hook path.

- [ ] **Step 1: Write the failing metadata contract tests**

Create `tests/test_metadata.py` with `unittest`, load JSON from the repository
root, and assert these exact contracts:

```python
#!/usr/bin/env python3
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def commands(document, event):
    return [item for group in document["hooks"][event] for item in group["hooks"]]


class PluginContracts(unittest.TestCase):
    def test_codex_manifest_uses_default_discovery(self):
        manifest = load(".codex-plugin/plugin.json")
        self.assertEqual("hark", manifest["name"])
        self.assertNotIn("hooks", manifest)
        self.assertIn("interface", manifest)

    def test_claude_manifest_selects_its_hook_file(self):
        self.assertEqual("./hooks/claude.json", load(".claude-plugin/plugin.json")["hooks"])

    def test_codex_event_roles(self):
        hooks = load("hooks/hooks.json")
        expected = {
            "Stop": "done",
            "PermissionRequest": "attention",
            "SubagentStop": "subagent",
            "SessionEnd": "bye",
        }
        self.assertEqual(set(expected), set(hooks["hooks"]))
        for event, role in expected.items():
            command = commands(hooks, event)[0]
            self.assertIn(f'hark.sh\" {role}', command["command"])
            self.assertIn("PLUGIN_ROOT", command["command"])
            self.assertIn(role, command["commandWindows"])
            self.assertNotIn("async", command)

    def test_claude_event_roles_use_documented_fields(self):
        hooks = load("hooks/claude.json")
        expected = {
            "Stop": "done",
            "PermissionRequest": "attention",
            "PostToolUseFailure": "error",
            "StopFailure": "error",
            "SubagentStop": "subagent",
            "SessionEnd": "bye",
        }
        self.assertEqual(set(expected), set(hooks["hooks"]))
        for event, role in expected.items():
            command = commands(hooks, event)[0]
            self.assertIn(f'hark.sh\" {role}', command["command"])
            self.assertIn("CLAUDE_PLUGIN_ROOT", command["command"])
            self.assertTrue(command["async"])
            self.assertNotIn("commandWindows", command)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to prove the contract is absent**

Run: `python3 tests/test_metadata.py`

Expected: `ERROR` for missing `.codex-plugin/plugin.json` and/or failures for
the current shared Claude hook mapping.

- [ ] **Step 3: Add the Codex manifest**

Create `.codex-plugin/plugin.json` with no `hooks` field:

```json
{
  "name": "hark",
  "version": "0.1.0",
  "description": "Short sound notifications when Codex finishes, needs attention, or completes background work.",
  "author": {
    "name": "Antonio Giordano",
    "url": "https://github.com/sdv0001"
  },
  "homepage": "https://github.com/sdv0001/hark",
  "repository": "https://github.com/sdv0001/hark",
  "license": "MIT",
  "keywords": ["notification", "sound", "hooks", "productivity", "agent"],
  "interface": {
    "displayName": "hark",
    "shortDescription": "Hear when Codex needs you.",
    "longDescription": "Plays short local sounds when Codex finishes a turn, requests permission, completes a subagent, or ends a session.",
    "developerName": "Antonio Giordano",
    "category": "Productivity",
    "capabilities": [],
    "defaultPrompt": "Configure hark sound notifications."
  }
}
```

- [ ] **Step 4: Split the hook files**

Replace `hooks/hooks.json` with four Codex events. Every POSIX command has this
shape, substituting the role, so Codex returns without waiting for audio:

```json
{
  "type": "command",
  "command": "sh \"${PLUGIN_ROOT}/scripts/hark.sh\" done >/dev/null 2>&1 &",
  "commandWindows": "Start-Process -FilePath powershell -WindowStyle Hidden -WorkingDirectory $env:PLUGIN_ROOT -ArgumentList '-NoProfile','-File','scripts\\hark.ps1','done'",
  "timeout": 10
}
```

Use the event-role table from the test. Create `hooks/claude.json` with the six
Claude events from the test; every command uses this shape with the matching
role and contains no `commandWindows`:

```json
{
  "type": "command",
  "command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/hark.sh\" done",
  "async": true,
  "timeout": 10
}
```

Change `.claude-plugin/plugin.json` to:

```json
"hooks": "./hooks/claude.json"
```

- [ ] **Step 5: Run and validate the contracts**

Run:

```bash
python3 tests/test_metadata.py
python3 /Users/antoniogiordano/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
```

Expected: `Ran 4 tests ... OK` and `Plugin validation passed`.

- [ ] **Step 6: Commit the native plugin contract**

```bash
git add .codex-plugin/plugin.json .claude-plugin/plugin.json hooks tests/test_metadata.py
git commit -m "feat: add native Codex plugin hooks"
```

---

### Task 2: Remove legacy Codex runtime and harden POSIX playback

**Files:**
- Modify: `tests/test.sh`
- Modify: `scripts/hark.sh`

**Interfaces:**
- Consumes: role names passed directly by every hook.
- Produces: `hark.sh <role>` and `hark.sh test`; no installer or JSON payload interface.

- [ ] **Step 1: Replace legacy tests with failing regression tests**

Delete the Codex payload and installer sections in `tests/test.sh`. Add tests
that create real temporary sound files where playback must occur:

```sh
custom="$TMP/custom.wav"
: > "$custom"
printf 'HARK_SOUND_DONE=%s\n' "$TMP/from-config.wav" > "$TMP/sound-env.conf"
: > "$TMP/from-config.wav"
out=$(HARK_CONF="$TMP/sound-env.conf" HARK_SOUND_DONE="$custom" sh "$HARK" test)
assert_contains "sound environment override beats config" "done -> $custom" "$out"

printf 'HARK_PRESET=subtle' > "$TMP/no-newline.conf"
out=$(HARK_CONF="$TMP/no-newline.conf" sh "$HARK" test)
assert_contains "final config line needs no newline" "subtle-done.wav" "$out"

for volume in 08 0009 999999999999999999999999999999999999; do
    out=$(HARK_VOLUME="$volume" HARK_PLAYER=echo sh "$HARK" done 2>&1)
    assert_contains "numeric volume $volume is safe" "sounds/done.wav" "$out"
done

mkdir -p "$TMP/bin"
player="$TMP/bin/custom-play"
printf '#!/bin/sh\nprintf "custom-play:%%s\\n" "$*"\n' > "$player"
chmod +x "$player"
out=$(HARK_PLAYER="$player" sh "$HARK" done)
assert_contains "explicit play path is invoked" "custom-play:" "$out"

ps_player="$TMP/bin/fake-powershell"
printf '#!/bin/sh\nprintf "file=%%s\\n" "$HARK_AUDIO_FILE"\nprintf "args=%%s\\n" "$*"\n' > "$ps_player"
chmod +x "$ps_player"
quoted="$TMP/a file with 'quote.wav"
: > "$quoted"
out=$(HARK_SOUND_DONE="$quoted" HARK_PLAYER="$ps_player" sh "$HARK" done)
assert_contains "PowerShell fallback receives path through environment" "file=$quoted" "$out"
assert_missing "PowerShell source does not contain the path" "$quoted" "$(printf '%s' "$out" | sed -n 's/^args=//p')"
```

Also assert help contains neither `codex` nor `install`.

- [ ] **Step 2: Run the POSIX suite and confirm the regressions**

Run: `sh tests/test.sh`

Expected: failures for sound precedence, the unterminated config line, volume
`08`, explicit player paths, and PowerShell path transport.

- [ ] **Step 3: Remove the legacy runtime**

Delete from `scripts/hark.sh`:

- the `codex` usage comment and `codex_role()`;
- `install_codex()` and its installer dispatch;
- the `codex` dispatch branch and legacy help lines.

Keep the public dispatch to `test`, direct roles, and help only.

- [ ] **Step 4: Correct config precedence and parsing**

Capture and restore all environment-controlled settings:

```sh
env_preset=$HARK_PRESET
env_volume=$HARK_VOLUME
env_player=$HARK_PLAYER
env_sound_done=$HARK_SOUND_DONE
env_sound_attention=$HARK_SOUND_ATTENTION
env_sound_error=$HARK_SOUND_ERROR
env_sound_subagent=$HARK_SOUND_SUBAGENT
env_sound_bye=$HARK_SOUND_BYE
```

Use one CR value and a loop that accepts an unterminated last line:

```sh
cr=$(printf '\r')
while IFS='=' read -r key value || [ -n "$key$value" ]; do
    value=${value%"$cr"}
    value=${value#\"}
    value=${value%\"}
    # existing allowlist case
done < "$conf"
```

Restore each non-empty captured sound setting after `read_conf`.

- [ ] **Step 5: Normalize volume without unsafe arithmetic**

Use lexical validation before shell arithmetic:

```sh
case "$HARK_VOLUME" in
    '' | *[!0-9]*) HARK_VOLUME=100 ;;
    *)
        while [ "${HARK_VOLUME#0}" != "$HARK_VOLUME" ]; do
            HARK_VOLUME=${HARK_VOLUME#0}
        done
        HARK_VOLUME=${HARK_VOLUME:-0}
        [ "${#HARK_VOLUME}" -gt 3 ] && HARK_VOLUME=100
        [ "$HARK_VOLUME" -gt 100 ] 2>/dev/null && HARK_VOLUME=100
        ;;
esac
```

- [ ] **Step 6: Invoke the chosen player safely**

Every suffix branch must execute `"$player"`, including afplay, paplay,
ffplay, aplay, and play. Replace PowerShell source interpolation with:

```sh
HARK_AUDIO_FILE=$file "$player" -NoProfile -Command \
    '(New-Object Media.SoundPlayer $env:HARK_AUDIO_FILE).PlaySync()'
```

- [ ] **Step 7: Run POSIX tests and lint**

Run:

```bash
sh tests/test.sh
dash tests/test.sh
shellcheck --shell=sh scripts/hark.sh tests/test.sh
```

Expected: all assertions pass and shellcheck emits no diagnostics.

- [ ] **Step 8: Commit the POSIX cleanup**

```bash
git add scripts/hark.sh tests/test.sh
git commit -m "fix: simplify and harden POSIX playback"
```

---

### Task 3: Remove legacy Codex behavior from PowerShell

**Files:**
- Modify: `tests/test.ps1`
- Modify: `scripts/hark.ps1`

**Interfaces:**
- Consumes: direct role argument from native hooks.
- Produces: the same five roles and `test` command as the POSIX entry point.

- [ ] **Step 1: Make PowerShell tests reject the legacy interface**

Delete all Codex payload assertions. Add:

```powershell
$out = Invoke-Hark @()
Assert-Missing 'help omits legacy codex mode' 'codex' $out
Assert-Missing 'help omits legacy installer' 'install' $out
```

- [ ] **Step 2: Run the PowerShell suite to prove the old help fails**

Run: `powershell -NoProfile -File tests/test.ps1`

Expected on Windows: two failing assertions because the current help advertises
`codex`.

- [ ] **Step 3: Delete the PowerShell parser and payload parameter**

Remove `$Payload`, `Get-CodexRole`, the `codex` switch branch, and Codex text
from comment-based help. Keep usage exactly:

```powershell
Write-Host 'usage: hark.ps1 <done|attention|error|subagent|bye|test>'
```

- [ ] **Step 4: Run the Windows-compatible suite**

Run: `powershell -NoProfile -File tests/test.ps1`

Expected: all assertions pass. If PowerShell is not installed locally, record
that fact and rely on the unchanged `windows-latest` CI job for execution.

- [ ] **Step 5: Commit the PowerShell cleanup**

```bash
git add scripts/hark.ps1 tests/test.ps1
git commit -m "refactor: remove legacy Codex payload handling"
```

---

### Task 4: Align documentation, release notes, and CI

**Files:**
- Modify: `README.md`
- Modify: `integrations/codex.md`
- Modify: `integrations/claude-code.md`
- Modify: `integrations/README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CHANGELOG.md`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: native plugin contracts and simplified runtime from Tasks 1-3.
- Produces: one accurate install, migration, support, and verification story.

- [ ] **Step 1: Add the metadata suite to CI**

In the POSIX job, after `sh tests/test.sh`, add:

```yaml
      - name: Validate plugin metadata
        run: python3 tests/test_metadata.py
```

Remove Ubuntu's redundant `apt-get install dash`; `ubuntu-latest` already
provides `/usr/bin/dash`. Keep `dash tests/test.sh` as the strict POSIX run.

- [ ] **Step 2: Rewrite Codex installation and migration docs**

README and `integrations/codex.md` must state:

```text
Minimum Codex version: 0.147.
Install with:
  codex plugin marketplace add sdv0001/hark
  codex plugin add hark@hark
Existing users: remove the top-level `notify = [...]` hark entry from
`~/.codex/config.toml`; the plugin does not need or read it.
```

Document the four event mappings, default `hooks/hooks.json` discovery,
`PLUGIN_ROOT`, the `/hooks` trust/reload check, and the absence of a truthful
Codex `error` event. Delete every claim that plugins cannot carry hooks.

- [ ] **Step 3: Align cross-agent documentation**

Update the README coverage table so Codex also covers `subagent` and `bye`.
Remove the Codex JSON exception from “How it works”. In
`integrations/README.md`, describe all three supported agents as one-command-
per-event hook integrations and remove `codex_role()` guidance. In
`integrations/claude-code.md`, replace `Notification` with
`PermissionRequest`, add `StopFailure`, and document Git Bash for Claude on
Windows.

- [ ] **Step 4: Update contributor and release documentation**

In `CONTRIBUTING.md`, add `python3 tests/test_metadata.py` to the required
checks and remove instructions to add payload parsers next to `codex_role()`.
In `CHANGELOG.md`, replace the current Unreleased legacy installer entries
with Added/Changed/Removed/Fixed bullets for native Codex hooks, split Claude
hooks, complete `notify` removal, and the five runtime corrections.

- [ ] **Step 5: Prove no legacy path remains**

Run:

```bash
rg -n 'install codex|codex_role|Get-CodexRole|agent-turn-complete|approval-requested|notify =|notify payload|Codex is the exception' --glob '!docs/plans/**' --glob '!docs/superpowers/plans/**' .
```

Expected: no matches. Mentions of removing the historical `notify` key are
allowed only in migration and changelog prose and should be reviewed manually.

- [ ] **Step 6: Commit documentation and CI**

```bash
git add README.md integrations CONTRIBUTING.md CHANGELOG.md .github/workflows/ci.yml
git commit -m "docs: document native Codex plugin setup"
```

---

### Task 5: Final verification and repository audit

**Files:**
- Modify only if verification exposes a defect.

**Interfaces:**
- Consumes: all prior deliverables.
- Produces: evidence that the repository is release-ready.

- [ ] **Step 1: Run the complete local verification matrix**

```bash
sh tests/test.sh
dash tests/test.sh
python3 tests/test_metadata.py
shellcheck --shell=sh scripts/hark.sh tests/test.sh
python3 /Users/antoniogiordano/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .
python3 tools/gen_sounds.py
git diff --exit-code -- sounds/
git diff --check
```

Expected: every test and validator passes, sounds are reproducible, and no diff
check errors appear.

- [ ] **Step 2: Run PowerShell verification where available**

```bash
powershell -NoProfile -File tests/test.ps1
```

Expected: all PowerShell assertions pass; otherwise explicitly report that
local PowerShell was unavailable and that Windows CI remains required.

- [ ] **Step 3: Review the final diff and repository state**

```bash
git diff f1bc389..HEAD --stat
git diff f1bc389..HEAD
git status --short
```

Expected: only in-scope plugin, hook, runtime, test, CI, and documentation
changes; clean working tree after any final verification commit.
