#!/usr/bin/env sh
# claude-chime — play a sound when Claude Code finishes or needs you.
#
#   chime.sh <role>     role: done | attention | error | subagent | bye
#   chime.sh test       play every role of the active preset, in order
#
# Deliberately POSIX sh with no jq, no node, no python: this runs on whatever
# shell the user happens to have. The hook payload arrives on stdin as JSON and
# we ignore it completely — the role is passed as an argument instead, which is
# the entire reason this script needs no JSON parser.
#
# Exits 0 in every path, including failure. A notifier that can break someone's
# session is worse than no notifier.

CHIME_ROOT=${CHIME_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
SOUNDS_DIR="$CHIME_ROOT/sounds"
ROLES="done attention error subagent bye"

# --------------------------------------------------------------------------
# config: built-in defaults < ~/.claude/chime.conf < environment
# --------------------------------------------------------------------------

# Remember what the environment set, so the file can never override it.
env_preset=$CHIME_PRESET
env_volume=$CHIME_VOLUME
env_player=$CHIME_PLAYER

read_conf() {
    conf=${CHIME_CONF:-$HOME/.claude/chime.conf}
    [ -f "$conf" ] || return 0

    # Read the file directly rather than piping it: a pipe would put the loop
    # in a subshell and every assignment below would be lost.
    while IFS='=' read -r key value; do
        # Strip CR so a file saved on Windows still parses.
        value=$(printf '%s' "$value" | tr -d '\r' | sed 's/^"//; s/"$//')
        case "$key" in
            CHIME_PRESET) CHIME_PRESET=$value ;;
            CHIME_VOLUME) CHIME_VOLUME=$value ;;
            CHIME_PLAYER) CHIME_PLAYER=$value ;;
            CHIME_SOUND_DONE) CHIME_SOUND_DONE=$value ;;
            CHIME_SOUND_ATTENTION) CHIME_SOUND_ATTENTION=$value ;;
            CHIME_SOUND_ERROR) CHIME_SOUND_ERROR=$value ;;
            CHIME_SOUND_SUBAGENT) CHIME_SOUND_SUBAGENT=$value ;;
            CHIME_SOUND_BYE) CHIME_SOUND_BYE=$value ;;
            *) ;;  # comments, blanks and anything unrecognised: ignored
        esac
    done < "$conf"

    # The config file is never sourced. It sits in a directory other tools
    # write to, and a config file should not be able to execute code.
    return 0
}

read_conf
[ -n "$env_preset" ] && CHIME_PRESET=$env_preset
[ -n "$env_volume" ] && CHIME_VOLUME=$env_volume
[ -n "$env_player" ] && CHIME_PLAYER=$env_player
CHIME_PRESET=${CHIME_PRESET:-default}
CHIME_VOLUME=${CHIME_VOLUME:-100}

# The volume reaches awk and shell arithmetic, and it comes from a file a human
# edits. Anything that is not 0-100 is a typo, not an intention.
case "$CHIME_VOLUME" in
    '' | *[!0-9]*) CHIME_VOLUME=100 ;;
    *) [ "$CHIME_VOLUME" -gt 100 ] && CHIME_VOLUME=100 ;;
esac

# --------------------------------------------------------------------------
# which file does (preset, role) mean?
# --------------------------------------------------------------------------

user_override() {
    case "$1" in
        done) printf '%s' "$CHIME_SOUND_DONE" ;;
        attention) printf '%s' "$CHIME_SOUND_ATTENTION" ;;
        error) printf '%s' "$CHIME_SOUND_ERROR" ;;
        subagent) printf '%s' "$CHIME_SOUND_SUBAGENT" ;;
        bye) printf '%s' "$CHIME_SOUND_BYE" ;;
    esac
}

# Prints the sound file for a role, or returns 1 to mean "stay silent".
resolve_sound() {
    role=$1

    override=$(user_override "$role")
    if [ -n "$override" ]; then
        printf '%s' "$override"
        return 0
    fi

    case "$CHIME_PRESET" in
        off)
            return 1
            ;;
        minimal)
            case "$role" in
                done | attention) printf '%s' "$SOUNDS_DIR/$role.wav" ;;
                *) return 1 ;;
            esac
            ;;
        subtle)
            printf '%s' "$SOUNDS_DIR/subtle-$role.wav"
            ;;
        macos)
            # System sounds. Silent on other platforms by design: the files
            # simply are not there, and play() skips what it cannot find.
            case "$role" in
                done) printf '%s' "/System/Library/Sounds/Glass.aiff" ;;
                attention) printf '%s' "/System/Library/Sounds/Funk.aiff" ;;
                error) printf '%s' "/System/Library/Sounds/Basso.aiff" ;;
                subagent) printf '%s' "/System/Library/Sounds/Tink.aiff" ;;
                bye) return 1 ;;
            esac
            ;;
        default | *)
            printf '%s' "$SOUNDS_DIR/$role.wav"
            ;;
    esac
}

# --------------------------------------------------------------------------
# playback
# --------------------------------------------------------------------------

detect_player() {
    for candidate in afplay paplay aplay ffplay play powershell.exe pwsh; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# 0-100 -> "0.00".."1.00" for the players that want a float. Done with integer
# arithmetic on purpose: piping the value through awk needs a layer of quoting
# that is easy to get wrong and puts a config value inside an evaluated string.
volume_float() {
    printf '%d.%02d' "$((CHIME_VOLUME / 100))" "$((CHIME_VOLUME % 100))"
}

# Named play_file, not play: sox ships a binary called `play`, and a shell
# function of the same name would call itself forever instead of it.
play_file() {
    file=$1
    [ -f "$file" ] || return 0  # e.g. the macos preset on Linux

    player=${CHIME_PLAYER:-$(detect_player)}
    [ -n "$player" ] || return 0

    # Order matters: *aplay, *paplay and *ffplay must be tested before the
    # bare *play that matches sox.
    case "$player" in
        *afplay)
            # afplay wants 0.0-2.0, our knob is 0-100.
            afplay -v "$(volume_float)" "$file"
            ;;
        *paplay)
            # PulseAudio volume is 0-65536.
            paplay --volume="$((CHIME_VOLUME * 655))" "$file"
            ;;
        *ffplay)
            ffplay -nodisp -autoexit -loglevel quiet -volume "$CHIME_VOLUME" "$file"
            ;;
        *aplay)
            aplay -q "$file"  # no volume control; CHIME_VOLUME is ignored
            ;;
        *play)
            command play -q -v "$(volume_float)" "$file"
            ;;
        *powershell.exe | *pwsh | *powershell)
            # Under Git Bash the path is /c/... which PowerShell cannot open.
            if command -v cygpath >/dev/null 2>&1; then
                file=$(cygpath -w "$file")
            fi
            "$player" -NoProfile -Command \
                "(New-Object Media.SoundPlayer '$file').PlaySync()"
            ;;
        *)
            # Anything else, including CHIME_PLAYER=echo, which is how the
            # test suite checks sound selection without making a noise.
            "$player" "$file"
            ;;
    esac
}

# --------------------------------------------------------------------------

case "${1:-}" in
    "" | -h | --help)
        echo "usage: chime.sh <done|attention|error|subagent|bye|test>" >&2
        exit 0
        ;;
    test)
        for role in $ROLES; do
            file=$(resolve_sound "$role") || continue
            echo "$role -> $file"
            play_file "$file"
        done
        ;;
    *)
        file=$(resolve_sound "$1") || exit 0
        play_file "$file"
        ;;
esac

exit 0
