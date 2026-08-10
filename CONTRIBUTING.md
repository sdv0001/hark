# Contributing

Thanks for looking. This is a small project on purpose — a shell script, a
PowerShell twin, and some generated WAVs. Please keep it that way.

## Getting set up

```sh
git clone https://github.com/sdv0001/claude-chime
cd claude-chime
sh tests/test.sh
```

That is the whole toolchain. No install step, no package manager. The tests
need no audio device and make no sound.

To try your change against a live Claude Code:

```
/plugin marketplace add /path/to/your/claude-chime
/plugin install claude-chime@claude-chime
```

## Before you open a pull request

- `sh tests/test.sh` passes.
- `shellcheck scripts/chime.sh tests/test.sh` is clean.
- If you touched `scripts/chime.sh`, make the same change in
  `scripts/chime.ps1`. They are deliberate twins — the same config file has to
  behave the same way on all three platforms. CI runs both.
- New behaviour comes with a test. The suite works by reading the
  `role -> file` table that `chime.sh test` prints, and by setting
  `CHIME_PLAYER=echo` to observe playback, so most things are testable without
  a sound card.

## Two rules that are not style preferences

**The script must exit 0 on every path.** Missing file, missing player,
malformed config, unknown role — all of it exits 0. This runs on someone's
every turn; it does not get to break their session.

**The config file is parsed, never sourced.** `~/.claude/chime.conf` sits in a
directory that several tools write to. Adding an `eval`, a `source`, or an
`Invoke-Expression` there will be rejected. There is a test guarding this in
both suites; if you find yourself wanting to delete it, open an issue instead.

## Adding a preset

1. Add a branch to the `case` in `scripts/chime.sh` and the `switch` in
   `scripts/chime.ps1`.
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
sh scripts/chime.sh test
```

That prints the resolution table, which is usually enough to spot the problem.
