"""The nine stage-1 crops in the hd style (32 x 44, base near row 42),
matching wheat, pumpkin and turnip in objects.py. Stage 0 is a seed
mound (game.seed_mound), 1 a sprout, 2 young, 3 ripe."""
import math
import random

from .draw import ball, glow, line, mix, new, outline, put, rect
from . import palette as P

R = P.RAMPS


def _ramp(name, cols):
    P.RAMPS.setdefault(name, cols)


def ramps():
    _ramp("carrot", ["#5a1e0c", "#8a3412", "#c4561a", "#e87a24", "#f8a040", "#ffc870"])
    _ramp("berry", ["#3a0c1e", "#6a1430", "#a02040", "#d03a52", "#f06a78", "#ffa0a8"])
    _ramp("bean", ["#2a3418", "#3e4e22", "#56682e", "#72863a", "#92a44a", "#b4c068"])
    _ramp("frost", ["#24405a", "#3a6484", "#5a8eb0", "#82b4d4", "#b0d8ee", "#e4f4fc"])
    _ramp("pepper", ["#4a0a0a", "#7a1410", "#b02418", "#e04028", "#f86a3e", "#ffa070"])
    _ramp("cotton", ["#8a8478", "#aaa496", "#c8c2b4", "#e0dcd0", "#f2f0e8", "#ffffff"])
    _ramp("melon", ["#1a3a1e", "#265a2a", "#348036", "#4aa444", "#78c45a", "#b0e07a"])
    _ramp("corn", ["#4a2a5a", "#6a3c80", "#8a52a4", "#a870c4", "#c898e0", "#e8c8f8"])
    _ramp("sun", ["#6a3a0a", "#a0600e", "#d08a18", "#f0b028", "#ffd040", "#fff090"])


def _leaf(im, x0, y0, ang, length, width=1.6):
    for k in range(int(length)):
        x = x0 + math.cos(ang) * k
        y = y0 + math.sin(ang) * k
        w = width * math.sin(math.pi * (k + 1) / (length + 1)) + 0.6
        ball(im, x, y, w, w * 0.8, "leaf", lo=0.25, hi=0.95)


def _stem(im, x, y0, y1, c=None):
    for y in range(int(y1), int(y0) + 1):
        put(im, x, y, c or R["leaf"][2])
        put(im, x + 1, y, R["leaf"][1])


def _tuft(im, x, base, n, length, spread=0.5):
    for i in range(n):
        ang = -math.pi / 2 + (i - (n - 1) / 2) * spread
        _leaf(im, x, base, ang, length)


def sprout(kind):
    im = new(32, 44)
    _stem(im, 16, 41, 34)
    _leaf(im, 16, 35, -math.pi * 0.85, 6, 1.4)
    _leaf(im, 17, 34, -math.pi * 0.15, 6, 1.4)
    if kind in ("suncrown", "stormcorn", "ironbean"):
        _leaf(im, 16, 33, -math.pi / 2, 6, 1.2)
    outline(im)
    return im


def carrot(stage):
    im = new(32, 44)
    if stage == 3:
        ball(im, 16, 39, 6, 4, "carrot", lo=0.3, hi=0.95)
        for y in (38, 40):
            put(im, 14, y, R["carrot"][1])
            put(im, 18, y + 1, R["carrot"][1])
    _tuft(im, 16, 37, 5 if stage == 3 else 4, 12 if stage == 3 else 10, 0.35)
    outline(im)
    return im


def suncrown(stage):
    im = new(32, 44)
    top = 10 if stage == 3 else 20
    _stem(im, 16, 41, top + 6)
    for y, d in ((34, -1), (28, 1), (22, -1)):
        if y > top + 6:
            _leaf(im, 16, y, -math.pi / 2 + d * 1.1, 7, 2.2)
    if stage == 3:
        for k in range(16):
            a = k / 16 * math.tau
            ball(im, 16 + math.cos(a) * 7, top + math.sin(a) * 6, 2.6, 2.2, "sun", lo=0.35, hi=1.0)
        ball(im, 16, top, 4.6, 4, "wood", lo=0.2, hi=0.7)
        for (x, y) in ((15, top - 1), (17, top + 1), (14, top + 1)):
            put(im, x, y, R["wood"][1])
    else:
        ball(im, 16, top, 3, 2.6, "leaf", lo=0.4, hi=0.9)
    outline(im)
    if stage == 3:
        glow(im, 16, top, 12, "#ffce50", 0.2)
    return im


def bloodberry(stage):
    im = new(32, 44)
    for (x, y, r) in ((10, 36, 6), (22, 36, 6), (16, 31, 7), (16, 37, 6)):
        ball(im, x, y, r, r * 0.8, "leaf", lo=0.15, hi=0.85)
    if stage == 3:
        rnd = random.Random(4)
        for _ in range(9):
            x, y = rnd.randint(8, 24), rnd.randint(28, 40)
            ball(im, x, y, 1.8, 1.8, "berry", lo=0.35, hi=1.0)
            put(im, x - 1, y - 1, "#ffffff")
    outline(im)
    return im


def ironbean(stage):
    im = new(32, 44)
    rect(im, 15, 8 if stage == 3 else 16, 16, 41, R["wood"][3])  # trellis pole
    put(im, 15, 8 if stage == 3 else 16, R["wood"][5])
    top = 12 if stage == 3 else 20
    for y in range(top, 40, 5):
        d = 1 if (y // 5) % 2 else -1
        _leaf(im, 16, y, -math.pi / 2 + d * 1.2, 6, 1.8)
    if stage == 3:
        for (x, y) in ((11, 22), (21, 27), (12, 33), (20, 17)):
            for k in range(6):
                ball(im, x, y + k, 1.4, 1.1, "bean", lo=0.4, hi=0.95)
    outline(im)
    return im


def frostcabbage(stage):
    im = new(32, 44)
    if stage == 2:
        for (x, y) in ((11, 37), (21, 37), (16, 34)):
            ball(im, x, y, 5, 3.6, "frost", lo=0.2, hi=0.8)
        outline(im)
        return im
    from . import objects as O
    return O.frost_cabbage()


def emberpepper(stage):
    im = new(32, 44)
    _stem(im, 16, 41, 24)
    for y, d in ((36, -1), (31, 1), (26, -1), (22, 1)):
        _leaf(im, 16, y, -math.pi / 2 + d * 1.0, 6, 2)
    if stage == 3:
        for (x, y) in ((11, 30), (21, 27), (14, 36), (20, 35)):
            for k in range(6):
                ball(im, x + k * 0.15, y + k, 1.8 - k * 0.2, 1.4, "pepper", lo=0.35, hi=1.0)
            put(im, x, y - 2, R["leaf"][3])
    outline(im)
    if stage == 3:
        glow(im, 16, 32, 12, "#ff7a3a", 0.18)
    return im


def cottonpuff(stage):
    im = new(32, 44)
    for (x0, ang) in ((16, -math.pi / 2), (16, -math.pi * 0.7), (16, -math.pi * 0.3)):
        for k in range(14 if stage == 3 else 9):
            put(im, x0 + math.cos(ang) * k, 41 + math.sin(ang) * k, R["wood"][3])
    _leaf(im, 16, 36, -math.pi * 0.9, 6, 1.6)
    _leaf(im, 16, 35, -math.pi * 0.1, 6, 1.6)
    for (x, y) in ((16, 26), (8, 31), (24, 31)) if stage == 3 else ((16, 31), (11, 34), (21, 34)):
        if stage == 3:
            ball(im, x, y, 4.4, 3.8, "cotton", lo=0.4, hi=1.0)
        else:
            ball(im, x, y, 2.4, 2.2, "leaf", lo=0.35, hi=0.95)
    outline(im)
    return im


def glowmelon(stage):
    im = new(32, 44)
    for (x, y) in ((6, 37), (26, 36), (10, 31)):
        ball(im, x, y, 4.4, 3, "leaf", lo=0.2, hi=0.9)
    if stage >= 2:
        r = 11 if stage == 3 else 6
        ball(im, 17, 41 - r * 0.75, r, r * 0.75, "melon", lo=0.15, hi=0.95)
        for k in range(-2, 3):  # stripes
            for y in range(int(41 - r * 1.5), 42):
                x = 17 + k * r * 0.38 + math.sin(y * 0.6) * 0.6
                if im.getpixel((int(x), y))[3] and im.getpixel((int(x), y))[1] > 60:
                    mix(im, x, y, "#1a4a20", 0.45)
    outline(im)
    if stage == 3:
        glow(im, 17, 33, 14, "#b0f080", 0.25)
    return im


def stormcorn(stage):
    im = new(32, 44)
    top = 6 if stage == 3 else 18
    for x in (12, 20):
        _stem(im, x, 41, top + 4)
        for y in range(top + 8, 40, 6):
            _leaf(im, x, y, -math.pi / 2 + (1.2 if (y // 6 + x) % 2 else -1.2), 7, 1.6)
    if stage == 3:
        for x in (12, 20):
            for k in range(9):
                ball(im, x + 1, 20 + k, 2.2, 1.2, "corn", lo=0.35, hi=1.0)
            put(im, x + 1, 19, "#fff4a0")
            line(im, x + 1, 18, x + 3, 15, "#f0e0a0")
        # a little spark of the storm
        line(im, 25, 8, 23, 12, "#fff4a0")
        line(im, 23, 12, 26, 12, "#fff4a0")
        line(im, 26, 12, 24, 16, "#fff4a0")
    outline(im)
    return im


DRAW = {
    "ashcarrot": carrot, "suncrown": suncrown, "bloodberry": bloodberry, "ironbean": ironbean,
    "frostcabbage": frostcabbage, "emberpepper": emberpepper, "cottonpuff": cottonpuff,
    "glowmelon": glowmelon, "stormcorn": stormcorn,
}


def sprites(seed_mound):
    ramps()
    s = {}
    for cid, fn in DRAW.items():
        s[cid + "_0"] = seed_mound("straw")
        s[cid + "_1"] = sprout(cid)
        s[cid + "_2"] = fn(2)
        s[cid + "_3"] = fn(3)
    return s
