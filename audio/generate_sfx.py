#!/usr/bin/env python3
"""Synthesizes DUSTBLOOM sound effects.

Organic, "premium casual" timbres built from scratch: FM marimba and bells,
plucked strings (Karplus-Strong), granular soil crunch, leaf rustle, bubble
pops, a soft pad, all through a stereo room reverb. Nothing is sampled, so
the game owns every sound outright.

Output: client/Dustbloom/Sounds/<name>.wav (44.1 kHz, 16-bit stereo) and
audio/sfx_demo.wav with every sound in a row.

Run from the repo root:  python3 audio/generate_sfx.py   (needs numpy, scipy)
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "client", "Dustbloom", "Sounds")
SR = 44100
rng = np.random.default_rng(11)


def n_(d):
    return int(SR * d)


def tt(d):
    return np.arange(n_(d)) / SR


def pad_to(x, n):
    return np.pad(x, (0, max(0, n - len(x))))


def at(x, delay):
    """Shift a mono signal later by delay seconds."""
    return np.concatenate([np.zeros(n_(delay)), x])


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(pad_to(p, n) for p in parts)


def band(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def noise(d):
    return rng.standard_normal(n_(d)) * 0.3


# ------------------------------------------------------------------ instruments
def declick(x, ms=25):
    """Fade the last few ms so a note never stops on a non-zero sample."""
    k = min(len(x), n_(ms / 1000))
    x = x.copy()
    x[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return x


def fm(f, d, ratio, index, idx_decay, amp_decay, attack=0.002):
    """Two-operator FM: the bread and butter of mallets and bells."""
    t = tt(d)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t * idx_decay)
    car = np.sin(2 * np.pi * f * t + mod)
    env = np.exp(-t * amp_decay)
    a = n_(attack)
    env[:a] *= np.linspace(0, 1, a)
    return declick(car * env)


def marimba(f, d=0.6, vol=0.5):
    tone = fm(f, d, 4.0, 2.2, 38, 9) + 0.35 * fm(f * 3.93, d, 1.0, 0.4, 30, 24)
    mallet = band(noise(0.012), 1500, 6000) * np.exp(-tt(0.012) * 300) * 0.6
    return mix(tone, mallet) * vol


def bell(f, d=1.8, vol=0.4):
    """Glockenspiel-like: inharmonic FM with a bright strike."""
    tone = fm(f, d, 3.5, 3.0, 6, 3.2) + 0.25 * fm(f * 2.76, d, 1.4, 1.0, 10, 6)
    return tone * vol


def wood(f, d=0.08, vol=0.5):
    """Wood block / button tick."""
    return (fm(f, d, 2.0, 3.0, 80, 60) + band(noise(d), 800, 3000) * np.exp(-tt(d) * 120) * 0.4) * vol


def pluck(f, d=0.5, vol=0.5, bright=0.5):
    """Karplus-Strong plucked string."""
    period = int(SR / f)
    buf = rng.uniform(-1, 1, period)
    buf = lp(buf, 2000 + 8000 * bright, 1)
    out = np.empty(n_(d))
    for i in range(len(out)):
        j = i % period
        out[i] = buf[j]
        buf[j] = 0.996 * 0.5 * (buf[j] + buf[(j + 1) % period])
    return declick(out * vol)


def bubble(f0, f1, d=0.05, vol=0.6):
    """Bubble/cork pop: a fast upward sine sweep with a sharp decay."""
    t = tt(d)
    f = f0 * (f1 / f0) ** (t / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 55) * vol


def rustle(d=0.25, vol=0.3):
    """Leaves: bandpassed noise with a jittery amplitude."""
    x = band(noise(d), 2500, 9000)
    jitter = np.repeat(rng.uniform(0.3, 1, int(d * 120) + 1), SR // 120 + 1)[: n_(d)]
    env = np.minimum(1, tt(d) / 0.02) * np.exp(-tt(d) * 9)
    return declick(x * jitter * env * vol * 3)


def crunch(d=0.16, grains=36, vol=0.5):
    """Dry soil: many tiny noise grains, each with its own colour."""
    out = np.zeros(n_(d) + n_(0.02))
    for _ in range(grains):
        start = rng.uniform(0, d) ** 1.6 / d ** 0.6  # denser at the start
        g = n_(rng.uniform(0.003, 0.012))
        c = rng.uniform(900, 5000)
        grain = band(noise(g / SR + 1e-4)[:g], c * 0.7, c * 1.3) * np.hanning(g)
        s = n_(start)
        out[s:s + g] += grain * rng.uniform(0.4, 1) * (1 - start / d * 0.7)
    return out * vol * 4


def thump(f0=110, f1=45, d=0.14, vol=0.7):
    t = tt(d)
    f = f0 * (f1 / f0) ** (t / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 28) * vol


def pad(freqs, d, vol=0.15):
    """Soft warm pad: detuned saws through a low-pass, slow swell."""
    t = tt(d)
    x = np.zeros(len(t))
    for f in freqs:
        for det in (-0.006, 0.0, 0.006):
            ph = (f * (1 + det) * t) % 1
            x += 2 * ph - 1
    x = lp(x, 1800, 2)
    env = np.minimum(1, t / 0.12) * np.exp(-np.maximum(0, t - 0.15) * 3.5)
    return declick(x * env * vol / (len(freqs) * 3))


# ------------------------------------------------------------------ space
def reverb(x, wet=0.2, size=1.0, damp=4500):
    """Small stereo room (Schroeder/Freeverb style). Returns (L, R)."""
    tail = n_(1.2 * size)
    x = pad_to(x, len(x) + tail)
    outs = []
    for side, spread in ((0, 0), (1, 23)):
        acc = np.zeros(len(x))
        for d_ms in (29.7, 37.1, 41.1, 43.7):
            D = int((d_ms * size) * SR / 1000) + spread
            g = 0.78
            a = np.zeros(D + 1)
            a[0], a[D] = 1, -g
            acc += lfilter([1], a, lp(x, damp, 1))
        for d_ms in (5.0, 1.7):
            D = int(d_ms * SR / 1000) + spread // 3
            b = np.zeros(D + 1)
            b[0], b[D] = -0.5, 1
            a = np.zeros(D + 1)
            a[0], a[D] = 1, -0.5
            acc = lfilter(b, a, acc)
        outs.append(hp(acc, 200) * wet * 0.25)
    return x + outs[0], x + outs[1]


def finish(x, wet=0.18, size=1.0, gain=1.0):
    """Reverb, gentle saturation, peak normalise to about -3 dBFS times gain."""
    l, r = reverb(x, wet, size)
    st = np.stack([l, r])
    st = np.tanh(st * 1.2) / np.tanh(1.2)
    # trim silent tail
    env = np.abs(st).max(axis=0)
    last = np.nonzero(env > 1e-3)[0]
    st = st[:, : (last[-1] + 1 if len(last) else st.shape[1])]
    st = st / (np.abs(st).max() + 1e-9) * 0.7 * gain
    fade = min(st.shape[1], n_(0.01))
    st[:, -fade:] *= np.linspace(1, 0, fade)
    return st


# ------------------------------------------------------------------ the sounds
def till():
    return finish(mix(crunch(0.17, 40, 0.6), thump(120, 50, 0.15, 0.8), lp(noise(0.1), 700) * np.exp(-tt(0.1) * 30) * 1.2),
                  wet=0.08, size=0.6, gain=0.9)


def plant():
    puff = band(noise(0.08), 250, 1400) * np.exp(-tt(0.08) * 45) * 1.6
    return finish(mix(puff, thump(160, 90, 0.08, 0.5), at(marimba(784, 0.35, 0.35), 0.03)), wet=0.15, gain=0.75)


def harvest():
    x = mix(
        bubble(380, 1300, 0.06, 0.8),
        rustle(0.22, 0.35),
        at(marimba(1047, 0.5, 0.45), 0.04),
        at(marimba(1568, 0.5, 0.35), 0.09),
        at(bell(3136, 0.6, 0.08), 0.12),
    )
    return finish(x, wet=0.2, gain=0.95)


def coin():
    x = mix(bell(1976, 0.7, 0.35), at(bell(2637, 0.9, 0.4), 0.07), at(pluck(1319, 0.3, 0.12, 0.9), 0.0))
    return finish(x, wet=0.22, gain=0.8)


def level_up():
    notes = (523, 659, 784, 1047)
    x = mix(
        *(at(marimba(f, 0.6, 0.5), i * 0.085) for i, f in enumerate(notes)),
        at(bell(2093, 1.6, 0.25), 0.34), at(bell(2637, 1.6, 0.18), 0.37), at(bell(3136, 1.6, 0.14), 0.40),
        at(pad((262, 330, 392, 523), 1.6, 0.6), 0.3),
        at(rustle(0.5, 0.12), 0.32),
    )
    return finish(x, wet=0.32, size=1.3, gain=1.0)


def error():
    x = mix(lp(marimba(220, 0.35, 0.6), 1800), at(lp(marimba(175, 0.4, 0.6), 1600), 0.11))
    return finish(x, wet=0.1, gain=0.6)


def select():
    return finish(mix(wood(1400, 0.07, 0.6), at(wood(2100, 0.05, 0.25), 0.012)), wet=0.08, gain=0.5)


def sparkle():
    x = mix(bell(3520, 0.6, 0.2), at(bell(4186, 0.6, 0.15), 0.06), at(bell(5274, 0.5, 0.1), 0.11))
    return finish(hp(x, 1500), wet=0.35, size=1.2, gain=0.35)


SOUNDS = {
    "sfx_till": till, "sfx_plant": plant, "sfx_harvest": harvest, "sfx_coin": coin,
    "sfx_levelup": level_up, "sfx_error": error, "sfx_select": select, "sfx_sparkle": sparkle,
}


def write(path, st):
    data = (np.clip(st.T, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    demo = []
    for name, fn in SOUNDS.items():
        st = fn()
        write(os.path.join(OUT, name + ".wav"), st)
        demo += [st, np.zeros((2, n_(0.5)))]
    write(os.path.join(ROOT, "audio", "sfx_demo.wav"), np.concatenate(demo, axis=1))
    print("wrote %d sounds" % len(SOUNDS))


if __name__ == "__main__":
    main()
