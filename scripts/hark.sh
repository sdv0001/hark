#!/usr/bin/env sh
# hark — play a sound when a coding agent finishes or needs you.
#
#   hark.sh <role>          role: done | attention | error | subagent | bye
#   hark.sh test            play every role of the active preset, in order
#   hark.sh codex <json>    map a Codex notify payload to a role, then play it
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

read_conf() {
    # XDG rather than a dotfile under any one agent's directory: hark belongs
    # to none of them.
    conf=${HARK_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/hark/config}
    [ -f "$conf" ] || return 0

    # Read the file directly rather than piping it: a pipe would put the loop
    # in a subshell and every assignment below would be lost.
    while IFS='=' read -r key value; do
        # Strip CR so a file saved on Windows still parses.
        value=$(printf '%s' "$value" | tr -d '\r' | sed 's/^"//; s/"$//')
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
HARK_PRESET=${HARK_PRESET:-default}
HARK_VOLUME=${HARK_VOLUME:-100}

# The volume reaches shell arithmetic, and it comes from a file a human edits.
# Anything that is not 0-100 is a typo, not an intention.
case "$HARK_VOLUME" in
    '' | *[!0-9]*) HARK_VOLUME=100 ;;
    *) [ "$HARK_VOLUME" -gt 100 ] && HARK_VOLUME=100 ;;
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
# Codex hands its event type over as a JSON blob in argv, where every other
# agent lets us pass a plain role. Rather than take on a JSON parser for one
# field, match the field as a substring.
#
# Quotes are stripped before matching, not just whitespace: when the payload
# reaches a PowerShell entry point as an argument, PowerShell's -File parameter
# parsing eats the double quotes, and {"type":"x"} arrives as {type:x}. Both
# forms have to match or Codex is silent on Windows.
#
# ponytail: substring match, not parsing. A payload whose free-text message
# contains `type:agent-turn-complete` would be misread. Swap in jq (or
# `codex notify --json`, if it ever grows one) if that stops being far-fetched.
# --------------------------------------------------------------------------

codex_role() {
    compact=$(printf '%s' "$1" | tr -d '[:space:]"')
    case "$compact" in
        *type:agent-turn-complete*) printf 'done' ;;
        *type:approval-requested*) printf 'attention' ;;
        *) return 1 ;;
    esac
}

# --------------------------------------------------------------------------
# install: write the agent's own config for it
#
# Only agents that need a hand-edited file get an installer. Claude Code has
# a plugin mechanism and Gemini CLI takes a JSON block; Codex takes one
# absolute path in a top-level TOML key, which is exactly the shape that is
# annoying to type and easy to put in the wrong place.
#
# The line is prepended rather than appended. `notify` is top-level, so at the
# end of the file it would land inside whatever [section] came last and be
# read as `[that-section].notify` — no error, no sound, nothing to debug
# against. The top of the file is top-level scope no matter what follows.
# --------------------------------------------------------------------------

install_codex() {
    cfg=${CODEX_HOME:-$HOME/.codex}/config.toml

    # A TOML basic string: escape backslashes before quotes, or the backslashes
    # this adds would themselves be escaped.
    path=$(printf '%s' "$HARK_ROOT/scripts/hark.sh" | sed 's/\\/\\\\/g; s/"/\\"/g')
    line="notify = [\"/bin/sh\", \"$path\", \"codex\"]"

    if [ ! -f "$cfg" ]; then
        mkdir -p -- "$(dirname -- "$cfg")" || return 1
        (umask 077 && printf '%s\n' "$line" > "$cfg") || return 1
        printf 'hark: wrote %s\n' "$cfg"
        printf 'Restart Codex to pick it up.\n'
        return 0
    fi

    # Any notify key anywhere is a reason to stop, not just one at top level.
    # Codex honours a single notify program, and a second one added blindly
    # would be a duplicate key: TOML calls that an error and Codex would then
    # refuse the whole file. Refusing to edit is the recoverable failure.
    existing=$(grep -n '^[[:space:]]*notify[[:space:]]*=' "$cfg" | head -n 1)
    if [ -n "$existing" ]; then
        case "$existing" in
            *"$path"*)
                printf 'hark: already installed in %s\n' "$cfg"
                return 0
                ;;
        esac
        printf 'hark: %s already sets notify, leaving it alone:\n' "$cfg" >&2
        printf '  %s\n' "$existing" >&2
        printf 'Codex runs one notify program. To use hark, replace that line with:\n' >&2
        printf '  %s\n' "$line" >&2
        return 1
    fi

    # The backup doubles as the scratch copy: the file cannot be read and
    # rewritten in one pass, and redirecting into the original rather than
    # moving over it keeps its permissions, which are commonly 0600 here.
    cp -- "$cfg" "$cfg.bak" || return 1
    { printf '%s\n\n' "$line" && cat -- "$cfg.bak"; } > "$cfg" || return 1
    printf 'hark: added notify to %s (backup: %s.bak)\n' "$cfg" "$cfg"
    printf 'Restart Codex to pick it up.\n'
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
            afplay -v "$(volume_float)" "$file"
            ;;
        *paplay)
            # PulseAudio volume is 0-65536.
            paplay --volume="$((HARK_VOLUME * 655))" "$file"
            ;;
        *ffplay)
            ffplay -nodisp -autoexit -loglevel quiet -volume "$HARK_VOLUME" "$file"
            ;;
        *aplay)
            aplay -q "$file"  # no volume control; HARK_VOLUME is ignored
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
        echo "       hark.sh codex '<notify payload>'" >&2
        echo "       hark.sh install codex" >&2
        exit 0
        ;;
    install)
        case "${2:-}" in
            codex) install_codex ;;
            *)
                echo "usage: hark.sh install codex" >&2
                echo "Claude Code installs itself: /plugin install hark@hark" >&2
                echo "Gemini CLI needs a hooks block: see integrations/gemini.md" >&2
                exit 2
                ;;
        esac
        # The only path here that reports failure. The exit-0 rule protects
        # agent sessions from a broken notifier; this one is a human at a
        # prompt, and "it did nothing" has to be distinguishable from "done".
        exit $?
        ;;
    test)
        for role in $ROLES; do
            file=$(resolve_sound "$role") || continue
            echo "$role -> $file"
            play_file "$file"
        done
        ;;
    codex)
        role=$(codex_role "${2:-}") || exit 0
        file=$(resolve_sound "$role") || exit 0
        play_file "$file"
        ;;
    *)
        file=$(resolve_sound "$1") || exit 0
        play_file "$file"
        ;;
esac

exit 0
