# Contributing

Thanks for looking. This is a small project on purpose — a shell script, a
PowerShell twin, and some generated WAVs. Please keep it that way.

## Getting set up

```sh
git clone https://github.com/sdv0001/hark
cd hark
sh tests/test.sh
```

That is the whole toolchain. No install step, no package manager. The tests
need no audio device and make no sound.

To try your change against a live Claude Code:

```
/plugin marketplace add /path/to/your/hark
/plugin install hark@hark
```

## Before you open a pull request

- `sh tests/test.sh` passes.
- `shellcheck scripts/hark.sh tests/test.sh` is clean.
- If you touched `scripts/hark.sh`, make the same change in
  `scripts/hark.ps1`. They are deliberate twins — the same config file has to
  behave the same way on all three platforms. CI runs both.
- New behaviour comes with a test. The suite works by reading the
  `role -> file` table that `hark.sh test` prints, and by setting
  `HARK_PLAYER=echo` to observe playback, so most things are testable without
  a sound card.

## Two rules that are not style preferences

**The script must exit 0 on every path.** Missing file, missing player,
malformed config, unknown role — all of it exits 0. This runs on someone's
every turn; it does not get to break their session.

**The config file is parsed, never sourced.** `~/.claude/config` sits in a
directory that several tools write to. Adding an `eval`, a `source`, or an
`Invoke-Expression` there will be rejected. There is a test guarding this in
both suites; if you find yourself wanting to delete it, open an issue instead.

## Adding an agent

The most useful contribution, and usually the smallest. The core is a command —
`hark.sh <role>` — so an integration is just "make this agent run that".

1. Read [integrations/README.md](integrations/README.md) for the role contract.
2. Add `integrations/<agent>.md`: setup snippet, a coverage table, and how to
   check it works.
3. Map only the events that honestly mean the role. If the agent has no
   tool-failure event, leave `error` silent and say so in the table. Wiring a
   role to something that nearly means it is worse than silence — the user stops
   trusting every sound once one of them lies.
4. Add a column to the role table in the top-level README.
5. If the agent passes its event inside a payload rather than letting you name a
   role per event, add a mapping function next to `codex_role()` in both scripts,
   with tests in both suites. Please do not add a JSON dependency for it.

Say which version of the agent you tested against and link its hook docs. These
formats move, and the next person needs to know when yours went stale.

## Adding a preset

1. Add a branch to the `case` in `scripts/hark.sh` and the `switch` in
   `scripts/hark.ps1`.
2. If it needs new sounds, add them to `VOICES` in `tools/gen_sounds.py` and
   run it. Commit the generated WAVs — do not commit sounds from elsewhere,
   the "everything here is generated" property is what keeps the licensing
   simple.
3. Add assertions to both test suites.
4. Add a row to the preset table in the README.

## Reporting a bug

Include your OS, which of `afplay` / `paplay` / `aplay` / `ffplay` / `play` you
have, and the output of:

```sh
sh scripts/hark.sh test
```

That prints the resolution table, which is usually enough to spot the problem.
