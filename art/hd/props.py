"""Small farm props for the cozy daytime look: barrels, crates, mailbox,
bushes, flower boxes, log pile, mushrooms, hay bale, a dog, a bench.
They make the farm feel lived-in."""
import math
import random

from .draw import ball, line, mix, new, outline, put, rect
from .palette import RAMPS, dither, hash01, ramp_d

R = RAMPS


def barrel():
    im = new(16, 20)
    for y in range(2, 19):
        bulge = 1 if 5 < y < 16 else 0
        for x in range(2 - bulge, 14 + bulge):
            t = 0.78 - (x - 1) / 14 * 0.5
            if y in (5, 14):
                put(im, x, y, R["stone"][2 if x > 8 else 4])
                continue
            if (x - 1) % 4 == 0:
                t -= 0.15
            put(im, x, y, ramp_d("wood", t, x, y))
    for x in range(3, 13):
        put(im, x, 2, R["wood"][5] if x < 9 else R["wood"][4])
        put(im, x, 3, R["wood"][2])
    outline(im)
    return im


def crate(vegs=True):
    im = new(20, 18)
    for y in range(5, 17):
        for x in range(1, 19):
            t = 0.75 - (x / 19) * 0.4
            if y in (5, 16) or x in (1, 18):
                t -= 0.2
            put(im, x, y, ramp_d("wood", t, x, y))
    line(im, 2, 15, 17, 6, R["wood"][2])
    if vegs:
        for (x, c) in ((5, "pumpkin"), (10, "pumpkin"), (15, "pumpkin")):
            ball(im, x, 4, 3, 2.6, c, lo=0.3, hi=0.95)
        put(im, 10, 1, R["leaf"][3])
    outline(im)
    return im


def mailbox():
    im = new(14, 24)
    rect(im, 6, 10, 7, 23, R["wood"][3])
    put(im, 6, 10, R["wood"][4])
    for y in range(2, 11):
        for x in range(1, 13):
            if y < 4 and x in (1, 12):
                continue
            t = 0.75 - x / 13 * 0.4
            put(im, x, y, ramp_d("cloth_blue", t, x, y))
    rect(im, 12, 1, 13, 5, R["red"][2])
    put(im, 12, 1, R["red"][3])
    put(im, 3, 6, "#fff4e8")
    put(im, 4, 6, "#fff4e8")
    outline(im)
    return im


def bush(w=26, h=18, seed=1, berries=None):
    im = new(w, h)
    rnd = random.Random(seed)
    blobs = [(w * 0.3, h * 0.6, w * 0.3, h * 0.42), (w * 0.62, h * 0.52, w * 0.32, h * 0.46),
             (w * 0.46, h * 0.38, w * 0.26, h * 0.34)]
    for (bx, by, rx, ry) in blobs:
        ball(im, bx, by, rx, ry, "leaf", lo=0.15, hi=0.95)
    for _ in range(w * h // 14):
        bx, by, rx, ry = rnd.choice(blobs)
        a = rnd.random() * 6.283
        x, y = bx + math.cos(a) * rx * 0.7, by + math.sin(a) * ry * 0.7
        if im.getpixel((int(x), int(y)))[3]:
            lit = x + y < w * 0.7
            put(im, x, y, R["leaf"][5 if lit else 3])
    if berries:
        for _ in range(7):
            x, y = rnd.randrange(3, w - 3), rnd.randrange(3, h - 3)
            if im.getpixel((x, y))[3]:
                put(im, x, y, berries)
                put(im, x - 1, y - 1, "#ffffff")
    outline(im)
    return im


def flower_box(w=34):
    im = new(w, 16)
    for y in range(8, 15):
        for x in range(1, w - 1):
            put(im, x, y, ramp_d("wood", 0.7 - x / w * 0.35 - (0.2 if y in (8, 14) else 0), x, y))
    rnd = random.Random(w)
    cols = ("#ff7a8a", "#ffd34a", "#ffffff", "#c88aff", "#ff9a4a")
    for x in range(3, w - 3, 3):
        hgt = rnd.randint(3, 6)
        for k in range(hgt):
            put(im, x, 8 - k, R["leaf"][3])
        c = rnd.choice(cols)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
            put(im, x + dx, 8 - hgt + dy, c)
        put(im, x, 8 - hgt, "#ffce50")
    outline(im)
    return im


def log_pile():
    im = new(26, 16)
    for (cx, cy) in ((6, 11), (13, 11), (20, 11), (9, 5), (16, 5)):
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 4, cx + 5):
                d = math.hypot(x - cx, y - cy)
                if d <= 4:
                    c = R["straw"][4] if d < 1.5 else R["straw"][3] if d < 3 else R["wood"][2]
                    if 2.2 < d < 2.8:
                        c = R["wood"][3]
                    put(im, x, y, c)
    outline(im)
    return im


def hay_bale():
    im = new(22, 16)
    for y in range(3, 15):
        for x in range(1, 21):
            t = 0.85 - x / 21 * 0.4 - (0.2 if y > 12 else 0)
            if (x + y * 3) % 7 == 0:
                t += 0.1
            put(im, x, y, ramp_d("straw", t, x, y))
    for x in range(1, 21):
        put(im, x, 3, R["straw"][5])
    rect(im, 6, 3, 6, 14, R["wood"][2])
    rect(im, 15, 3, 15, 14, R["wood"][2])
    outline(im)
    return im


def mushrooms():
    im = new(12, 10)
    for (x, y, r) in ((3, 6, 2.6), (8, 5, 3.2)):
        rect(im, x, y, x, y + 3, "#fff4e8")
        ball(im, x, y, r, r * 0.7, "red", lo=0.3, hi=1.0)
        put(im, x - 1, y - 1, "#ffffff")
    outline(im)
    return im


def dog(frame=0):
    """A sleepy farm dog: original, ginger with a white chest."""
    im = new(22, 16)
    ball(im, 10, 10, 7, 4.2, "pumpkin", lo=0.3, hi=0.9)
    ball(im, 17, 7, 3.6, 3.2, "pumpkin", lo=0.35, hi=0.95)
    rect(im, 15, 3, 16, 5, R["pumpkin"][2])  # ear
    put(im, 20, 8, "#2a1a12")  # nose
    put(im, 17, 6, "#2a1a12")  # eye
    ball(im, 14, 11, 2.5, 2, "white", lo=0.5, hi=1.0)
    for x in (6, 9, 13, 15):
        rect(im, x, 13, x + 1, 15, R["pumpkin"][2])
    tail = (2, 6) if frame == 0 else (2, 9)
    line(im, 4, 9, tail[0], tail[1], R["pumpkin"][4])
    outline(im)
    return im


def bench():
    im = new(30, 16)
    for y in (5, 8):
        for x in range(1, 29):
            put(im, x, y, R["wood"][4] if y == 5 else R["wood"][3])
            put(im, x, y + 1, R["wood"][2])
    for x in (3, 26):
        rect(im, x, 9, x + 1, 15, R["wood"][2])
    rect(im, 1, 1, 28, 2, R["wood"][3])
    outline(im)
    return im


def stepping_stone(r=4):
    im = new(r * 2 + 3, r + 3)
    ball(im, r + 1, (r + 3) / 2, r, r * 0.55, "stone", lo=0.35, hi=1.0)
    outline(im)
    return im
