#!/usr/bin/env python3
"""Synthesizes DUSTBLOOM sound effects (retro style, matching the pixel art).

Every sound is generated from oscillators and noise, so the game owns all
rights to them. Output: client/Dustbloom/Sounds/<name>.wav (44.1 kHz, 16-bit mono)
and audio/sfx_demo.wav with all sounds in a row.

Run from the repo root:  python3 audio/generate_sfx.py   (needs numpy)
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "client", "Dustbloom", "Sounds")
SR = 44100
rng = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=None, curve=3.0):
    """Attack then exponential-ish decay over n samples."""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    rest = n - a
    e[a:] = (1 - np.linspace(0, 1, rest)) ** curve
    return e


def osc(freq, dur, kind="square", duty=0.5):
    """freq may be a number or an array (glide). Phase-accurate."""
    n = int(SR * dur)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if np.ndim(freq) == 0 else np.asarray(freq)
    phase = np.cumsum(f) / SR % 1.0
    if kind == "square":
        return np.where(phase < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(phase - 0.5) - 1
    if kind == "saw":
        return 2 * phase - 1
    return np.sin(2 * np.pi * phase)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be an array (sweep)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    y = np.zeros(n)
    for p in parts:
        y[: len(p)] += p
    return y


def note(f, dur, kind="square", vol=0.5, duty=0.5, curve=2.0):
    return osc(f, dur, kind, duty) * env(int(SR * dur), curve=curve) * vol


# ------------------------------------------------------------------ sounds
def till():
    """Spade into dry earth: filtered noise crunch with a low thump."""
    d = 0.18
    n = noise(d) * env(int(SR * d), 0.002, curve=4)
    crunch = lowpass(n, np.linspace(3500, 500, len(n))) * 0.9
    thump = note(np.linspace(140, 60, int(SR * 0.12)), 0.12, "sine", 0.7, curve=3)
    return mix(crunch, thump)


def plant():
    """Seed into soil: soft rising pop."""
    d = 0.11
    pop = note(np.linspace(320, 720, int(SR * d)), d, "sine", 0.6, curve=2.5)
    tick = lowpass(noise(0.03), 2000) * env(int(SR * 0.03), curve=5) * 0.3
    return mix(pop, tick)


def harvest():
    """Crop pops out: bright pluck plus a quick rising arpeggio."""
    pluck = note(np.linspace(900, 500, int(SR * 0.08)), 0.08, "tri", 0.6, curve=3)
    arp = seq(*(note(f, 0.055, "square", 0.22, duty=0.25) for f in (784, 988, 1319)))
    return mix(pluck, np.concatenate([np.zeros(int(SR * 0.04)), arp]))


def coin():
    """Classic two-note coin."""
    return seq(note(988, 0.06, "square", 0.3, duty=0.5, curve=0.5), note(1319, 0.22, "square", 0.3, duty=0.5, curve=2.5))


def level_up():
    """Fanfare arpeggio with a shimmering tail."""
    notes = (523, 659, 784, 1047)
    lead = seq(*(note(f, 0.09, "square", 0.25, duty=0.25, curve=1) for f in notes[:-1]),
               note(notes[-1], 0.45, "square", 0.25, duty=0.25, curve=2))
    bass = seq(note(131, 0.27, "tri", 0.5, curve=1), note(196, 0.45, "tri", 0.5, curve=2))
    tail = osc(2093 + 12 * np.sin(2 * np.pi * 9 * t(0.5)), 0.5, "sine") * env(int(SR * 0.5), curve=3) * 0.12
    return mix(lead, bass, np.concatenate([np.zeros(int(SR * 0.27)), tail]))


def error():
    """Two low descending blips: not angry, just 'nope'."""
    return seq(note(330, 0.07, "square", 0.25, duty=0.5, curve=0.8),
               note(247, 0.12, "square", 0.25, duty=0.5, curve=2), gap=0.02)


def select():
    """UI tick."""
    return note(1760, 0.035, "square", 0.18, duty=0.25, curve=3)


def sparkle():
    """Ripe-crop glint: tiny high shimmer."""
    return mix(note(2637, 0.12, "sine", 0.12, curve=3), np.concatenate([np.zeros(int(SR * 0.04)), note(3520, 0.1, "sine", 0.08, curve=3)]))


SOUNDS = {
    "sfx_till": till, "sfx_plant": plant, "sfx_harvest": harvest, "sfx_coin": coin,
    "sfx_levelup": level_up, "sfx_error": error, "sfx_select": select, "sfx_sparkle": sparkle,
}


def write(path, y):
    y = np.clip(y, -1, 1)
    fade = min(len(y), int(SR * 0.004))
    y[-fade:] *= np.linspace(1, 0, fade)  # no click at the end
    data = (y * 32767 * 0.9).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    demo = []
    for name, fn in SOUNDS.items():
        y = fn()
        write(os.path.join(OUT, name + ".wav"), y.copy())
        demo += [y, np.zeros(int(SR * 0.45))]
    write(os.path.join(ROOT, "audio", "sfx_demo.wav"), np.concatenate(demo))
    print("wrote %d sounds" % len(SOUNDS))


if __name__ == "__main__":
    main()
