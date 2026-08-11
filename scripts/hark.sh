#!/usr/bin/env sh
# hark — play a sound when a coding agent finishes or needs you.
#
#   hark.sh <role>          role: done | attention | error | subagent | bye
#   hark.sh test            play every role of the active preset, in order
#
# Nothing here knows which agent invoked it. Agents differ in how they signal;
# they all agree on running a command. Each integration turns its own events
# into one of the roles above and calls this script — see integrations/.
#
# Deliberately POSIX sh with no jq, no node, no python: this runs on whatever
# shell the user happens to have.
#
# Exits 0 in every path, including failure. A notifier that can break someone's
# session is worse than no notifier.

HARK_ROOT=${HARK_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
SOUNDS_DIR="$HARK_ROOT/sounds"
ROLES="done attention error subagent bye"

# --------------------------------------------------------------------------
# config: built-in defaults < config file < environment
# --------------------------------------------------------------------------

# Remember what the environment set, so the file can never override it.
env_preset=$HARK_PRESET
env_volume=$HARK_VOLUME
env_player=$HARK_PLAYER
env_sound_done=$HARK_SOUND_DONE
env_sound_attention=$HARK_SOUND_ATTENTION
env_sound_error=$HARK_SOUND_ERROR
env_sound_subagent=$HARK_SOUND_SUBAGENT
env_sound_bye=$HARK_SOUND_BYE

read_conf() {
    # XDG rather than a dotfile under any one agent's directory: hark belongs
    # to none of them.
    conf=${HARK_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/hark/config}
    [ -f "$conf" ] || return 0

    # Read the file directly rather than piping it: a pipe would put the loop
    # in a subshell and every assignment below would be lost.
    cr=$(printf '\r')
    while IFS='=' read -r key value || [ -n "$key$value" ]; do
        # Strip CR so a file saved on Windows still parses.
        value=${value%"$cr"}
        value=${value#\"}
        value=${value%\"}
        case "$key" in
            HARK_PRESET) HARK_PRESET=$value ;;
            HARK_VOLUME) HARK_VOLUME=$value ;;
            HARK_PLAYER) HARK_PLAYER=$value ;;
            HARK_SOUND_DONE) HARK_SOUND_DONE=$value ;;
            HARK_SOUND_ATTENTION) HARK_SOUND_ATTENTION=$value ;;
            HARK_SOUND_ERROR) HARK_SOUND_ERROR=$value ;;
            HARK_SOUND_SUBAGENT) HARK_SOUND_SUBAGENT=$value ;;
            HARK_SOUND_BYE) HARK_SOUND_BYE=$value ;;
            *) ;;  # comments, blanks and anything unrecognised: ignored
        esac
    done < "$conf"

    # The config file is never sourced. It is a settings file, and a settings
    # file has no business executing code.
    return 0
}

read_conf
[ -n "$env_preset" ] && HARK_PRESET=$env_preset
[ -n "$env_volume" ] && HARK_VOLUME=$env_volume
[ -n "$env_player" ] && HARK_PLAYER=$env_player
[ -n "$env_sound_done" ] && HARK_SOUND_DONE=$env_sound_done
[ -n "$env_sound_attention" ] && HARK_SOUND_ATTENTION=$env_sound_attention
[ -n "$env_sound_error" ] && HARK_SOUND_ERROR=$env_sound_error
[ -n "$env_sound_subagent" ] && HARK_SOUND_SUBAGENT=$env_sound_subagent
[ -n "$env_sound_bye" ] && HARK_SOUND_BYE=$env_sound_bye
HARK_PRESET=${HARK_PRESET:-default}
HARK_VOLUME=${HARK_VOLUME:-100}

# The volume reaches shell arithmetic, and it comes from a file a human edits.
# Anything that is not 0-100 is a typo, not an intention.
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

# --------------------------------------------------------------------------
# which file does (preset, role) mean?
# --------------------------------------------------------------------------

user_override() {
    case "$1" in
        done) printf '%s' "$HARK_SOUND_DONE" ;;
        attention) printf '%s' "$HARK_SOUND_ATTENTION" ;;
        error) printf '%s' "$HARK_SOUND_ERROR" ;;
        subagent) printf '%s' "$HARK_SOUND_SUBAGENT" ;;
        bye) printf '%s' "$HARK_SOUND_BYE" ;;
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

    case "$HARK_PRESET" in
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
            # simply are not there, and play_file skips what it cannot find.
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
    printf '%d.%02d' "$((HARK_VOLUME / 100))" "$((HARK_VOLUME % 100))"
}

# Named play_file, not play: sox ships a binary called `play`, and a shell
# function of the same name would call itself forever instead of it.
play_file() {
    file=$1
    [ -f "$file" ] || return 0  # e.g. the macos preset on Linux

    player=${HARK_PLAYER:-$(detect_player)}
    [ -n "$player" ] || return 0

    # Order matters: *aplay, *paplay and *ffplay must be tested before the
    # bare *play that matches sox.
    case "$player" in
        *afplay)
            # afplay wants 0.0-2.0, our knob is 0-100.
            "$player" -v "$(volume_float)" "$file"
            ;;
        *paplay)
            # PulseAudio volume is 0-65536.
            "$player" --volume="$((HARK_VOLUME * 655))" "$file"
            ;;
        *ffplay)
            "$player" -nodisp -autoexit -loglevel quiet -volume "$HARK_VOLUME" "$file"
            ;;
        *aplay)
            "$player" -q "$file"  # no volume control; HARK_VOLUME is ignored
            ;;
        *play)
            "$player" -q -v "$(volume_float)" "$file"
            ;;
        *powershell.exe | *pwsh | *powershell)
            # Under Git Bash the path is /c/... which PowerShell cannot open.
            if command -v cygpath >/dev/null 2>&1; then
                file=$(cygpath -w "$file")
            fi
            # shellcheck disable=SC2016  # PowerShell expands its own $env value.
            HARK_AUDIO_FILE=$file "$player" -NoProfile -Command \
                '(New-Object Media.SoundPlayer $env:HARK_AUDIO_FILE).PlaySync()'
            ;;
        *)
            # Anything else, including HARK_PLAYER=echo, which is how the test
            # suite checks sound selection without making a noise.
            "$player" "$file"
            ;;
    esac
}

# --------------------------------------------------------------------------

case "${1:-}" in
    "" | -h | --help)
        echo "usage: hark.sh <done|attention|error|subagent|bye|test>" >&2
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
