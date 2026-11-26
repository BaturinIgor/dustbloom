"""Builds the game's sound effects from the CC0 Kenney packs in source/kenney.

Each sound is decoded with ffmpeg, softened (high-shelf cut, low-pass) so
nothing sounds harsh on a phone speaker, trimmed of silence, faded out, and
levelled to the same loudness so no effect jumps out. Output: 16-bit mono
44.1 kHz WAVs in client/Dustbloom/Sounds (AVAudioPlayer can't play ogg).

Run: python3 audio/build_sfx.py   (needs ffmpeg and numpy)
"""
import os
import subprocess
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "source", "kenney")
OUT = os.path.join(HERE, "..", "client", "Dustbloom", "Sounds")
RATE = 44100

# name: (source files layered together, target loudness in dBFS RMS)
SOUNDS = {
    "sfx_till": (["rpg-audio/footstep03.ogg"], -20),
    "sfx_plant": (["interface-sounds/drop_002.ogg"], -22),
    "sfx_harvest": (["interface-sounds/pluck_002.ogg"], -19),
    "sfx_coin": (["rpg-audio/handleCoins2.ogg"], -20),
    "sfx_levelup": (["music-jingles/jingles_PIZZA02.ogg"], -18),
    "sfx_error": (["interface-sounds/error_004.ogg"], -22),
    "sfx_select": (["interface-sounds/select_002.ogg"], -24),
    "sfx_sparkle": (["interface-sounds/glass_002.ogg"], -22),
    "sfx_chest": (["rpg-audio/metalLatch.ogg", "interface-sounds/confirmation_001.ogg"], -19),
    "sfx_speedup": (["interface-sounds/maximize_003.ogg"], -21),
    "sfx_victory": (["music-jingles/jingles_PIZZA15.ogg"], -18),
    "sfx_defeat": (["music-jingles/jingles_PIZZA14.ogg"], -20),
}

SOFTEN = "highshelf=f=6500:g=-5,lowpass=f=11000"


def decode(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-af", SOFTEN, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, np.int16).astype(np.float64) / 32768


def trim(a, floor=0.003):
    idx = np.where(np.abs(a) > floor)[0]
    if len(idx) == 0:
        return a
    return a[max(0, idx[0] - 64): idx[-1] + 1]


def build(files, target_db):
    layers = [trim(decode(os.path.join(SRC, f))) for f in files]
    n = max(len(x) for x in layers)
    a = np.zeros(n)
    for i, x in enumerate(layers):
        start = int(0.06 * RATE) * i  # layered sounds follow each other slightly
        a = np.pad(a, (0, max(0, start + len(x) - len(a))))
        a[start:start + len(x)] += x
    fade = min(len(a) // 4, int(0.03 * RATE))
    a[-fade:] *= np.linspace(1, 0, fade)
    a[:32] *= np.linspace(0, 1, 32)
    # level by the loud part only, so short clicks and long jingles match
    loud = a[np.abs(a) > 0.02] if np.any(np.abs(a) > 0.02) else a
    rms = np.sqrt(np.mean(loud ** 2))
    a *= 10 ** (target_db / 20) / max(rms, 1e-6)
    peak = np.max(np.abs(a))
    if peak > 0.89:  # -1 dBFS ceiling
        a *= 0.89 / peak
    return a


def write(path, a):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype("<i2").tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (files, db) in SOUNDS.items():
        a = build(files, db)
        write(os.path.join(OUT, name + ".wav"), a)
        print("%-12s %.2fs peak %.1f dB" % (name, len(a) / RATE, 20 * np.log10(np.max(np.abs(a)))))


if __name__ == "__main__":
    main()
