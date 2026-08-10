#!/usr/bin/env sh
# Self-check for hark.sh. No audio, no network, no framework.
#
#   sh tests/test.sh
#
# Two tricks make this possible:
#   - `hark.sh test` prints "role -> file" before playing, so the whole
#     preset/role resolution table is observable without a sound card.
#   - HARK_PLAYER=echo replaces the player, so playback is observable too.

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
HARK="$ROOT/scripts/hark.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Never read the developer's real config.
NOCONF="$TMP/absent.conf"
export HARK_CONF="$NOCONF"

# Keep the suite silent and fast: `echo` stands in for the audio player
# everywhere. Individual cases override it when that is the thing under test.
# Consequence worth knowing: the real afplay/paplay/... argument lists are not
# exercised here. CI has no sound card either way.
export HARK_PLAYER='echo'

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
}

no() {
    fail=$((fail + 1))
    printf '  FAIL %s\n' "$1"
    printf '       expected: %s\n' "$2"
    printf '       actual:   %s\n' "$3"
}

# assert_contains <name> <needle> <haystack>
assert_contains() {
    case "$3" in
        *"$2"*) ok "$1" ;;
        *) no "$1" "contains '$2'" "$3" ;;
    esac
}

# assert_missing <name> <needle> <haystack>
assert_missing() {
    case "$3" in
        *"$2"*) no "$1" "does NOT contain '$2'" "$3" ;;
        *) ok "$1" ;;
    esac
}

assert_equals() {
    if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "$2" "$3"; fi
}

echo "hark.sh self-check"

# --- preset: default ------------------------------------------------------
out=$(HARK_PRESET=default sh "$HARK" test)
assert_contains "default/done maps to done.wav" "done -> $ROOT/sounds/done.wav" "$out"
assert_contains "default/error maps to error.wav" "error -> $ROOT/sounds/error.wav" "$out"
assert_contains "default/bye is audible" "bye -> $ROOT/sounds/bye.wav" "$out"

# --- preset: subtle -------------------------------------------------------
out=$(HARK_PRESET=subtle sh "$HARK" test)
assert_contains "subtle/done maps to subtle-done.wav" "$ROOT/sounds/subtle-done.wav" "$out"
assert_missing "subtle never uses the loud set" "sounds/done.wav" "$out"

# --- preset: minimal ------------------------------------------------------
out=$(HARK_PRESET=minimal sh "$HARK" test)
assert_contains "minimal keeps done" "done -> " "$out"
assert_contains "minimal keeps attention" "attention -> " "$out"
assert_missing "minimal silences error" "error -> " "$out"
assert_missing "minimal silences subagent" "subagent -> " "$out"

# --- preset: off ----------------------------------------------------------
out=$(HARK_PRESET=off sh "$HARK" test)
assert_equals "off resolves nothing at all" "" "$out"

# --- preset: macos --------------------------------------------------------
out=$(HARK_PRESET=macos sh "$HARK" test)
assert_contains "macos/done is Glass" "/System/Library/Sounds/Glass.aiff" "$out"
assert_missing "macos has no bye sound" "bye -> " "$out"

# --- unknown preset falls back to default ---------------------------------
out=$(HARK_PRESET=nonsense sh "$HARK" test)
assert_contains "unknown preset behaves as default" "$ROOT/sounds/done.wav" "$out"

# --- config file ----------------------------------------------------------
printf '# a comment\nHARK_PRESET=subtle\n\n' > "$TMP/basic.conf"
out=$(HARK_CONF="$TMP/basic.conf" sh "$HARK" test)
assert_contains "config file selects the preset" "subtle-done.wav" "$out"

out=$(HARK_CONF="$TMP/basic.conf" HARK_PRESET=macos sh "$HARK" test)
assert_contains "environment beats config file" "Glass.aiff" "$out"

printf 'HARK_PRESET=default\nHARK_SOUND_DONE=/tmp/mine.wav\n' > "$TMP/override.conf"
out=$(HARK_CONF="$TMP/override.conf" sh "$HARK" test)
assert_contains "per-role override wins" "done -> /tmp/mine.wav" "$out"
assert_contains "other roles keep the preset" "error.wav" "$out"

# Windows line endings must not leak into the value.
printf 'HARK_PRESET=subtle\r\n' > "$TMP/crlf.conf"
out=$(HARK_CONF="$TMP/crlf.conf" sh "$HARK" test)
assert_contains "CRLF config parses" "subtle-done.wav" "$out"

# --- the config file must never be executed -------------------------------
canary="$TMP/canary"
# shellcheck disable=SC2016  # the literal $(...) is what must NOT be run
printf 'HARK_PRESET=default\n$(touch %s)\n`touch %s`\n' "$canary" "$canary" > "$TMP/evil.conf"
HARK_CONF="$TMP/evil.conf" sh "$HARK" test > /dev/null 2>&1
if [ -f "$canary" ]; then
    no "config file is not executed" "no canary file" "canary was created"
else
    ok "config file is not executed"
fi

# --- volume is sanitised before it reaches awk ----------------------------
out=$(HARK_VOLUME='50; rm -rf /' HARK_PLAYER='echo' sh "$HARK" "done" 2>&1)
assert_contains "garbage volume still plays" "sounds/done.wav" "$out"
out=$(HARK_VOLUME=9999 HARK_PLAYER='echo' sh "$HARK" "done" 2>&1)
assert_contains "out-of-range volume still plays" "sounds/done.wav" "$out"

# --- playback path --------------------------------------------------------
out=$(HARK_PLAYER='echo' sh "$HARK" "done")
assert_equals "player receives the resolved file" "$ROOT/sounds/done.wav" "$out"

out=$(HARK_PRESET=off HARK_PLAYER='echo' sh "$HARK" "done")
assert_equals "off plays nothing" "" "$out"

# --- never breaks the session ---------------------------------------------
HARK_PLAYER='echo' sh "$HARK" "done" > /dev/null 2>&1
assert_equals "exit 0 on a known role" 0 $?

HARK_PLAYER='echo' sh "$HARK" not_a_role > /dev/null 2>&1
assert_equals "exit 0 on an unknown role" 0 $?

sh "$HARK" > /dev/null 2>&1
assert_equals "exit 0 with no argument" 0 $?

HARK_PLAYER=/does/not/exist sh "$HARK" "done" > /dev/null 2>&1
assert_equals "exit 0 when the player is missing" 0 $?

# --- Codex payloads map to roles without a JSON parser --------------------
out=$(HARK_PLAYER='echo' sh "$HARK" codex '{"type":"agent-turn-complete","last-assistant-message":"ok"}')
assert_equals "codex turn-complete plays done" "$ROOT/sounds/done.wav" "$out"

out=$(HARK_PLAYER='echo' sh "$HARK" codex '{"type":"approval-requested"}')
assert_equals "codex approval-requested plays attention" "$ROOT/sounds/attention.wav" "$out"

# Whitespace between the key and the value must not defeat the match.
out=$(HARK_PLAYER='echo' sh "$HARK" codex '{ "type" : "agent-turn-complete" }')
assert_equals "codex payload with spaces still matches" "$ROOT/sounds/done.wav" "$out"

out=$(HARK_PLAYER='echo' sh "$HARK" codex '{"type":"something-else"}')
assert_equals "unknown codex event is silent" "" "$out"

out=$(HARK_PLAYER='echo' sh "$HARK" codex 'not json at all')
assert_equals "malformed codex payload is silent" "" "$out"

sh "$HARK" codex > /dev/null 2>&1
assert_equals "exit 0 when codex payload is missing" 0 $?

# --- every bundled sound the presets promise actually exists --------------
missing=""
for f in "done" attention error subagent bye; do
    [ -f "$ROOT/sounds/$f.wav" ] || missing="$missing $f.wav"
    [ -f "$ROOT/sounds/subtle-$f.wav" ] || missing="$missing subtle-$f.wav"
done
assert_equals "all bundled sounds are present" "" "$missing"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
