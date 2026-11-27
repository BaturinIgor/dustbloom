#!/usr/bin/env python3
"""Synthesizes the DUSTBLOOM biome music loops. Nothing is sampled, so the game owns them.

Each biome gets its own mode, tempo and instruments:
  meadow   C major pentatonic, marimba + pluck + soft pad, light shaker
  sand     E phrygian dominant, oud-like pluck + hand drums, warm drone
  mushroom D dorian, woody marimba low + muted bells, slow
  volcano  A minor, low toms, dark pad, sparse bell
  star     F lydian, celesta + airy pad, no drums

Loops are seamless (the reverb tail wraps to the start). Output:
client/Dustbloom/Sounds/music_<biome>.m4a (AAC, 22 kHz mono, ~64 kbps).

Run from the repo root:  python3 audio/generate_music.py   (needs numpy, scipy, ffmpeg)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "client", "Dustbloom", "Sounds")
SR = 22050


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.exp(-np.linspace(0, 6, nr))
    return e


def marimba(f, d):
    t = np.arange(int(d * SR)) / SR
    x = np.sin(2 * np.pi * f * t + 1.2 * np.exp(-t * 18) * np.sin(2 * np.pi * f * 4 * t))
    x += 0.25 * np.sin(2 * np.pi * f * 3.9 * t) * np.exp(-t * 20)
    return x * np.exp(-t * 5)


def bell(f, d):
    t = np.arange(int(d * SR)) / SR
    x = np.sin(2 * np.pi * f * t + 2.0 * np.exp(-t * 3) * np.sin(2 * np.pi * f * 3.5 * t))
    return x * np.exp(-t * 2.2) * 0.8


def pluck(f, d, bright=0.5):
    n = int(d * SR)
    p = max(2, int(SR / f))
    rng = np.random.default_rng(int(f))
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * (0.993 + 0.005 * bright)
    return out * env(n, 0.002, 0.05)


def pad(fs, d, air=0.0):
    t = np.arange(int(d * SR)) / SR
    x = np.zeros_like(t)
    for f in fs:
        for det in (-0.12, 0.0, 0.13):
            x += np.sin(2 * np.pi * f * (1 + det / 100) * t + np.sin(2 * np.pi * 0.3 * t))
    x /= max(1, len(fs) * 3)
    if air:
        x += air * np.random.default_rng(3).normal(0, 1, len(t)) * 0.05
    return x * env(len(t), d * 0.3, d * 0.3)


def noise_hit(d, lo, hi, decay, seed):
    n = int(d * SR)
    x = np.random.default_rng(seed).normal(0, 1, n)
    x = sosfilt(butter(2, [lo, hi], 'band', fs=SR, output='sos'), x)
    return x * np.exp(-np.arange(n) / SR * decay)


def tom(f, d):
    t = np.arange(int(d * SR)) / SR
    fr = f * (1 + 0.6 * np.exp(-t * 30))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 9)


def reverb(x, wet=0.3, size=1.0):
    out = x.copy()
    for k, (dl, g) in enumerate([(0.037, 0.5), (0.053, 0.45), (0.071, 0.4), (0.097, 0.35), (0.131, 0.3)]):
        d = int(dl * size * SR)
        y = np.zeros_like(x)
        for rep in range(1, 7):
            s = d * rep
            if s >= len(x):
                break
            y[s:] += x[:-s] * g ** rep
        out += wet * y / 3
    return out


BIOMES = {
    # name: root midi, scale, bpm, chords (scale degrees), lead, bass, drums, pad air
    'meadow': dict(root=60, scale=[0, 2, 4, 7, 9], bpm=96, chords=[0, 3, 4, 1], lead=marimba, drums='shaker', air=0),
    'sand': dict(root=52, scale=[0, 1, 4, 5, 7, 8, 10], bpm=84, chords=[0, 1, 0, 6], lead=lambda f, d: pluck(f, d, 0.9), drums='hand', air=0.3),
    'mushroom': dict(root=50, scale=[0, 2, 3, 5, 7, 9, 10], bpm=76, chords=[0, 3, 0, 6], lead=marimba, drums='wood', air=0),
    'volcano': dict(root=45, scale=[0, 2, 3, 5, 7, 8, 10], bpm=70, chords=[0, 5, 3, 4], lead=bell, drums='tom', air=0.5),
    'star': dict(root=65, scale=[0, 2, 4, 6, 7, 9, 11], bpm=72, chords=[0, 1, 4, 3], lead=bell, drums=None, air=1.0),
}


def note(cfg, deg, octave=0):
    sc = cfg['scale']
    o, i = divmod(deg, len(sc))
    return cfg['root'] + 12 * (o + octave) + sc[i]


def render(name, cfg):
    beat = 60 / cfg['bpm']
    bars = 16
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR * 4)
    rng = np.random.default_rng(sum(map(ord, name)) * 7)

    def put(x, t, g):
        i = int(t * SR)
        mix[i:i + len(x)] += x[: len(mix) - i] * g

    # melody motif A (2 bars), varied B; form A A' B A
    def motif(seed):
        r = np.random.default_rng(seed)
        out, deg, t = [], 4, 0.0
        while t < 8:
            dur = r.choice([0.5, 1, 1, 1.5, 2]) if t < 7 else 8 - t
            dur = min(dur, 8 - t)
            if r.random() > 0.18:
                out.append((t, deg, dur))
            deg = int(np.clip(deg + r.choice([-2, -1, -1, 1, 1, 2, 3]), 0, len(cfg['scale']) * 2))
            t += dur
        return out
    a, b, c = (motif(rng.integers(1e6)) for _ in range(3))
    a2 = [(t, d + (1 if i % 3 == 0 else 0), du) for i, (t, d, du) in enumerate(a)]
    c2 = [(t, d - 1 if i % 2 else d, du) for i, (t, d, du) in enumerate(c)]
    form = [a, a2, b, a, c, c2, b, a2]
    for k, m in enumerate(form):
        for t, deg, du in m:
            f = hz(note(cfg, deg, 0))
            put(cfg['lead'](f, min(du * beat + 0.6, 3)), (k * 8 + t) * beat, 0.22)

    for bar in range(bars):
        ch = cfg['chords'][bar % len(cfg['chords'])]
        t0 = bar * 4 * beat
        tones = [hz(note(cfg, ch + j, -1)) for j in (0, 2, 4)]
        put(pad(tones, 4 * beat + 0.4, cfg['air']), t0, 0.16)
        bassf = hz(note(cfg, ch, -2))
        for q in ((0, 2) if cfg['bpm'] < 80 else (0, 1.5, 2.5)):
            put(pluck(bassf, beat * 1.4, 0.2), t0 + q * beat, 0.3)
        d = cfg['drums']
        for s in range(8):
            ts = t0 + s * beat / 2
            if d == 'shaker':
                put(noise_hit(0.08, 4000, 9000, 60, s), ts, 0.05 if s % 2 else 0.08)
            elif d == 'hand':
                if s in (0, 3, 6):
                    put(tom(130, 0.3), ts, 0.25)
                if s in (2, 5, 7):
                    put(noise_hit(0.1, 1500, 5000, 40, s), ts, 0.08)
            elif d == 'wood' and s % 2 == 0:
                put(noise_hit(0.05, 1200, 3000, 90, s) + 0.5 * tom(600, 0.05), ts, 0.07)
            elif d == 'tom' and s in (0, 5):
                put(tom(70, 0.6), ts, 0.35)

    mix = reverb(mix, 0.35 if name != 'star' else 0.6, 1.4 if name in ('star', 'volcano') else 1.0)
    loop = mix[:total].copy()
    tail = mix[total:]
    loop[: len(tail)] += tail[: len(loop)]
    loop = sosfilt(butter(1, 30, 'high', fs=SR, output='sos'), loop)
    loop *= 0.5 / (np.sqrt(np.mean(loop ** 2)) * 6 + 1e-9)  # about -22 dB RMS, quieter than sfx
    loop = np.clip(loop, -0.98, 0.98)
    return loop


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, cfg in BIOMES.items():
        x = render(name, cfg)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            w = wave.open(f.name, 'wb')
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((x * 32767).astype('<i2').tobytes())
            w.close()
            dst = os.path.join(OUT, f'music_{name}.m4a')
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f.name, '-c:a', 'aac', '-b:a', '64k', dst], check=True)
            os.unlink(f.name)
        print(name, f'{len(x) / SR:.1f}s', os.path.getsize(dst) // 1024, 'KB')


if __name__ == '__main__':
    main()
