#!/usr/bin/env python3
"""Generate the WAV files bundled in sounds/.

    python3 tools/gen_sounds.py

Stdlib only, so every sound in this repo is reproducible from source and
unambiguously ours to license. Nothing is downloaded, nothing is sampled.

WAV (not AIFF/MP3) because it is the one format every player we shell out to
can read: afplay, paplay, aplay, ffplay, sox and PowerShell's SoundPlayer.
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050  # sine blips under 1 kHz; 22.05 kHz halves the repo weight
PEAK = 0.89  # leave headroom so no player clips on playback

SOUNDS_DIR = Path(__file__).resolve().parent.parent / "sounds"

# Each note is (start_seconds, frequency_hz, duration_seconds, amplitude).
# Notes may overlap; they are summed.
VOICES = {
    # E5 -> B5. Rising, bright: the turn is done.
    "done": [(0.00, 659.25, 0.55, 0.50), (0.09, 987.77, 0.45, 0.50)],
    # D5 D5 G5. Repetition reads as "come back", not "all good".
    "attention": [
        (0.00, 587.33, 0.50, 0.28),
        (0.18, 587.33, 0.50, 0.28),
        (0.36, 783.99, 0.55, 0.34),
    ],
    # G3 -> D#3. Low and falling: something broke.
    "error": [(0.00, 196.00, 0.50, 0.50), (0.10, 155.56, 0.45, 0.55)],
    # A5 blip. Deliberately the shortest sound: background work, not your turn.
    "subagent": [(0.00, 880.00, 0.35, 0.22)],
    # C5 -> G4. Soft fall, session closed.
    "bye": [(0.00, 523.25, 0.40, 0.40), (0.13, 392.00, 0.30, 0.45)],
}

# The "subtle" preset is the same shapes, quieter and shorter.
SUBTLE_GAIN = 0.35
SUBTLE_LENGTH = 0.7


def tone(freq, dur, amp, decay=6.0):
    """One plucked note: exponential decay, 5 ms attack so it does not click."""
    n = max(1, int(RATE * dur))
    attack = max(1, int(RATE * 0.005))
    for i in range(n):
        env = math.exp(-decay * i / n)
        if i < attack:
            env *= i / attack
        yield amp * env * math.sin(2 * math.pi * freq * i / RATE)


def render(notes, tail=0.05):
    """Mix notes into one float buffer."""
    total = max(start + dur for start, _, dur, _ in notes) + tail
    buf = [0.0] * int(RATE * total)
    for start, freq, dur, amp in notes:
        offset = int(RATE * start)
        for i, sample in enumerate(tone(freq, dur, amp)):
            buf[offset + i] += sample
    return buf


def write_wav(path, buf):
    """Write 16-bit mono. Scales down to avoid clipping, never up: a quiet
    sound must stay quiet, otherwise the subtle preset is not subtle."""
    peak = max(abs(s) for s in buf) or 1e-9
    scale = min(1.0, PEAK / peak)
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in buf
    )
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main():
    SOUNDS_DIR.mkdir(exist_ok=True)
    for role, notes in VOICES.items():
        write_wav(SOUNDS_DIR / f"{role}.wav", render(notes))
        quiet = [
            (start, freq, dur * SUBTLE_LENGTH, amp * SUBTLE_GAIN)
            for start, freq, dur, amp in notes
        ]
        write_wav(SOUNDS_DIR / f"subtle-{role}.wav", render(quiet))
    total = sum(p.stat().st_size for p in SOUNDS_DIR.glob("*.wav"))
    print(f"wrote {len(list(SOUNDS_DIR.glob('*.wav')))} files, {total // 1024} KB")


if __name__ == "__main__":
    main()
