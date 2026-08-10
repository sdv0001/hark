#!/usr/bin/env sh
# Self-check for chime.sh. No audio, no network, no framework.
#
#   sh tests/test.sh
#
# Two tricks make this possible:
#   - `chime.sh test` prints "role -> file" before playing, so the whole
#     preset/role resolution table is observable without a sound card.
#   - CHIME_PLAYER=echo replaces the player, so playback is observable too.

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHIME="$ROOT/scripts/chime.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Never read the developer's real config.
NOCONF="$TMP/absent.conf"
export CHIME_CONF="$NOCONF"

# Keep the suite silent and fast: `echo` stands in for the audio player
# everywhere. Individual cases override it when that is the thing under test.
# Consequence worth knowing: the real afplay/paplay/... argument lists are not
# exercised here. CI has no sound card either way.
export CHIME_PLAYER='echo'

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

echo "chime.sh self-check"

# --- preset: default ------------------------------------------------------
out=$(CHIME_PRESET=default sh "$CHIME" test)
assert_contains "default/done maps to done.wav" "done -> $ROOT/sounds/done.wav" "$out"
assert_contains "default/error maps to error.wav" "error -> $ROOT/sounds/error.wav" "$out"
assert_contains "default/bye is audible" "bye -> $ROOT/sounds/bye.wav" "$out"

# --- preset: subtle -------------------------------------------------------
out=$(CHIME_PRESET=subtle sh "$CHIME" test)
assert_contains "subtle/done maps to subtle-done.wav" "$ROOT/sounds/subtle-done.wav" "$out"
assert_missing "subtle never uses the loud set" "sounds/done.wav" "$out"

# --- preset: minimal ------------------------------------------------------
out=$(CHIME_PRESET=minimal sh "$CHIME" test)
assert_contains "minimal keeps done" "done -> " "$out"
assert_contains "minimal keeps attention" "attention -> " "$out"
assert_missing "minimal silences error" "error -> " "$out"
assert_missing "minimal silences subagent" "subagent -> " "$out"

# --- preset: off ----------------------------------------------------------
out=$(CHIME_PRESET=off sh "$CHIME" test)
assert_equals "off resolves nothing at all" "" "$out"

# --- preset: macos --------------------------------------------------------
out=$(CHIME_PRESET=macos sh "$CHIME" test)
assert_contains "macos/done is Glass" "/System/Library/Sounds/Glass.aiff" "$out"
assert_missing "macos has no bye sound" "bye -> " "$out"

# --- unknown preset falls back to default ---------------------------------
out=$(CHIME_PRESET=nonsense sh "$CHIME" test)
assert_contains "unknown preset behaves as default" "$ROOT/sounds/done.wav" "$out"

# --- config file ----------------------------------------------------------
printf '# a comment\nCHIME_PRESET=subtle\n\n' > "$TMP/basic.conf"
out=$(CHIME_CONF="$TMP/basic.conf" sh "$CHIME" test)
assert_contains "config file selects the preset" "subtle-done.wav" "$out"

out=$(CHIME_CONF="$TMP/basic.conf" CHIME_PRESET=macos sh "$CHIME" test)
assert_contains "environment beats config file" "Glass.aiff" "$out"

printf 'CHIME_PRESET=default\nCHIME_SOUND_DONE=/tmp/mine.wav\n' > "$TMP/override.conf"
out=$(CHIME_CONF="$TMP/override.conf" sh "$CHIME" test)
assert_contains "per-role override wins" "done -> /tmp/mine.wav" "$out"
assert_contains "other roles keep the preset" "error.wav" "$out"

# Windows line endings must not leak into the value.
printf 'CHIME_PRESET=subtle\r\n' > "$TMP/crlf.conf"
out=$(CHIME_CONF="$TMP/crlf.conf" sh "$CHIME" test)
assert_contains "CRLF config parses" "subtle-done.wav" "$out"

# --- the config file must never be executed -------------------------------
canary="$TMP/canary"
# shellcheck disable=SC2016  # the literal $(...) is what must NOT be run
printf 'CHIME_PRESET=default\n$(touch %s)\n`touch %s`\n' "$canary" "$canary" > "$TMP/evil.conf"
CHIME_CONF="$TMP/evil.conf" sh "$CHIME" test > /dev/null 2>&1
if [ -f "$canary" ]; then
    no "config file is not executed" "no canary file" "canary was created"
else
    ok "config file is not executed"
fi

# --- volume is sanitised before it reaches awk ----------------------------
out=$(CHIME_VOLUME='50; rm -rf /' CHIME_PLAYER='echo' sh "$CHIME" "done" 2>&1)
assert_contains "garbage volume still plays" "sounds/done.wav" "$out"
out=$(CHIME_VOLUME=9999 CHIME_PLAYER='echo' sh "$CHIME" "done" 2>&1)
assert_contains "out-of-range volume still plays" "sounds/done.wav" "$out"

# --- playback path --------------------------------------------------------
out=$(CHIME_PLAYER='echo' sh "$CHIME" "done")
assert_equals "player receives the resolved file" "$ROOT/sounds/done.wav" "$out"

out=$(CHIME_PRESET=off CHIME_PLAYER='echo' sh "$CHIME" "done")
assert_equals "off plays nothing" "" "$out"

# --- never breaks the session ---------------------------------------------
CHIME_PLAYER='echo' sh "$CHIME" "done" > /dev/null 2>&1
assert_equals "exit 0 on a known role" 0 $?

CHIME_PLAYER='echo' sh "$CHIME" not_a_role > /dev/null 2>&1
assert_equals "exit 0 on an unknown role" 0 $?

sh "$CHIME" > /dev/null 2>&1
assert_equals "exit 0 with no argument" 0 $?

CHIME_PLAYER=/does/not/exist sh "$CHIME" "done" > /dev/null 2>&1
assert_equals "exit 0 when the player is missing" 0 $?

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
