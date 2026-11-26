"""Scarecrow units (36 x 48) and raid enemies (40 x 40) in the hd style, for
the workshop and raid cards. Original designs."""
import math

from .draw import ball, glow, line, new, outline, put, rect
from . import palette as P

R = P.RAMPS


def _pole(im, x, y0, y1):
    wd = R["wood"]
    rect(im, x - 1, y0, x + 1, y1, wd[3])
    rect(im, x - 1, y0, x - 1, y1, wd[4])


def _cape(im, cx, top, bottom, half0, ramp, lo=0.2, hi=0.8):
    for y in range(top, bottom):
        half = half0 + (y - top) * 0.45
        hem = bottom - 2 + int(2 * math.sin(y * 0.0 + cx))
        for x in range(int(cx - half), int(cx + half) + 1):
            if y > bottom - 3 + int(2 * math.sin(x * 0.9)):
                continue
            fold = math.sin((x - cx) * 0.6)
            t = lo + (hi - lo) * (0.6 - (x - cx) / (half * 2.4)) + fold * 0.08
            put(im, x, y, P.ramp_d(ramp, t, x, y))


def _straw_hat(im, cx, y):
    for x in range(cx - 10, cx + 11):
        put(im, x, y, "#e8c46a")
        put(im, x, y + 1, "#b8903e")
    for yy in range(y - 6, y):
        for x in range(cx - 5, cx + 6):
            put(im, x, yy, "#f0d47a" if x < cx + 1 else "#d0aa50")
    rect(im, cx - 5, y - 2, cx + 5, y - 1, "#c84a3e")


def _sack_head(im, cx, cy, r=6.5):
    ball(im, cx, cy, r, r, "straw", lo=0.45, hi=1.0)
    for (x, y) in ((cx - 3, cy - 1), (cx + 2, cy - 1)):
        rect(im, x, y, x + 1, y + 1, "#2a1a12")
    line(im, cx - 3, cy + 3, cx + 3, cy + 3, "#6a3a20")
    for k in range(-3, 4, 2):
        put(im, cx + k, cy + 4, "#6a3a20")


def straw_guard():
    im = new(36, 48)
    _pole(im, 18, 22, 47)
    rect(im, 4, 22, 31, 23, R["wood"][3])
    _cape(im, 18, 22, 40, 6, "cloth_blue")
    _sack_head(im, 18, 16)
    _straw_hat(im, 18, 10)
    # shield
    ball(im, 9, 31, 5, 6, "wood", lo=0.3, hi=0.9)
    rect(im, 8, 26, 9, 36, R["gold"][3])
    return outline(im)


def pumpkin_brute():
    im = new(36, 48)
    _pole(im, 18, 26, 47)
    _cape(im, 18, 22, 44, 9, "cloth_red", 0.25, 0.75)
    ball(im, 18, 14, 10, 8.5, "pumpkin", lo=0.15, hi=0.95)
    for (x, y) in ((13, 12), (21, 12)):
        rect(im, x, y, x + 2, y + 1, "#ffe080")
    line(im, 12, 18, 24, 18, "#ffe080")
    for x in (14, 18, 22):
        put(im, x, 19, "#ffe080")
    rect(im, 17, 4, 18, 6, R["leaf"][2])
    # club
    rect(im, 29, 18, 31, 40, R["wood"][3])
    ball(im, 30, 18, 3.4, 4.2, "wood", lo=0.35, hi=0.95)
    return outline(im)


def moon_witch():
    im = new(36, 48)
    _pole(im, 18, 30, 47)
    _cape(im, 18, 20, 44, 6, "cape", 0.15, 0.7)
    _sack_head(im, 18, 17, 6)
    for y in range(0, 12):  # pointed hat
        half = 1 + y * 0.9
        for x in range(int(18 - half), int(18 + half) + 1):
            put(im, x, y, "#3c2a58" if x < 19 else "#2a1e40")
    rect(im, 6, 11, 30, 12, "#3c2a58")
    put(im, 20, 4, "#ffe080")
    # moon staff
    rect(im, 5, 14, 5, 44, R["wood"][4])
    ball(im, 5, 11, 3.2, 3.2, "white", lo=0.6, hi=1.0)
    put(im, 6, 10, "#3c2a58")
    im = outline(im)
    glow(im, 5, 11, 8, "#c2b0e0", 0.35)
    return im


def crow_archer():
    im = new(36, 48)
    _pole(im, 18, 26, 47)
    _cape(im, 18, 22, 42, 6, "leaf", 0.15, 0.6)
    _sack_head(im, 18, 17, 6)
    # hood
    for y in range(8, 16):
        for x in range(10, 27):
            if ((x + 0.5 - 18) / 8.4) ** 2 + ((y + 0.5 - 15) / 7.4) ** 2 <= 1 and y < 14:
                put(im, x, y, P.ramp_d("leaf", 0.5 - (x - 10) / 40, x, y))
    # crow on the shoulder
    ball(im, 27, 21, 3.4, 2.6, "cape", lo=0.05, hi=0.35)
    ball(im, 29, 18, 2, 2, "cape", lo=0.05, hi=0.4)
    put(im, 31, 18, "#f0a02e")
    put(im, 29, 17, "#ffe080")
    # bow
    for k in range(-12, 13):
        put(im, 7 + abs(k) * abs(k) / 40, 30 + k, R["wood"][4])
    line(im, 8, 18, 8, 42, "#e8e0d0")
    return outline(im)


def frost_sentinel():
    im = new(36, 48)
    _pole(im, 18, 30, 47)
    _cape(im, 18, 20, 44, 10, "frost", 0.25, 0.8)
    ball(im, 18, 14, 9, 8, "frost", lo=0.35, hi=1.0)  # cabbage-leaf helm
    for k in range(-2, 3):
        line(im, 18 + k * 3, 7, 18 + k * 2, 13, "#e4f4fc")
    rect(im, 13, 15, 23, 16, "#24405a")
    put(im, 15, 15, "#b0f0ff")
    put(im, 21, 15, "#b0f0ff")
    # tower shield
    for y in range(24, 42):
        for x in range(3, 12):
            put(im, x, y, P.ramp_d("stone", 0.7 - (x - 3) / 20, x, y))
    rect(im, 6, 27, 8, 38, "#b0d8ee")
    return outline(im)


def storm_shaman():
    im = new(36, 48)
    _pole(im, 18, 30, 47)
    _cape(im, 18, 20, 44, 7, "corn", 0.15, 0.7)
    _sack_head(im, 18, 16, 6)
    for k in range(5):  # corn-husk crown
        line(im, 12 + k * 3, 10, 11 + k * 3 + (k % 2), 4, "#f0e0a0")
    # staff with a spark
    rect(im, 30, 10, 30, 44, R["wood"][4])
    for (a, b) in (((30, 2), (27, 6)), ((27, 6), (31, 6)), ((31, 6), (28, 11))):
        line(im, *a, *b, "#fff4a0")
    im = outline(im)
    glow(im, 29, 6, 9, "#fff4a0", 0.45)
    return im


# ------------------------------------------------------------------ enemies
def _eyes(im, pts, c="#ff4a3a"):
    for (x, y) in pts:
        put(im, x, y, c)


def dust_rats():
    im = new(40, 40)
    for (cx, cy, s) in ((12, 28, 1.0), (27, 30, 1.1), (20, 20, 0.9)):
        ball(im, cx, cy, 7 * s, 4.6 * s, "dust", lo=0.15, hi=0.7)
        ball(im, cx + 6 * s, cy - 2, 3.4 * s, 3 * s, "dust", lo=0.2, hi=0.75)
        put(im, cx + 8 * s, cy - 3, "#ff4a3a")
        put(im, cx + 5 * s, cy - 6, "#e88a80")
        line(im, cx - 7 * s, cy, cx - 12 * s, cy - 3, "#c08878")
    return outline(im)


def rust_bandits():
    im = new(40, 40)
    for (cx, s) in ((12, 0.9), (28, 1.0)):
        ball(im, cx, 30, 6 * s, 8 * s, "pumpkin", lo=0.05, hi=0.4)
        ball(im, cx, 17, 5 * s, 5 * s, "skin", lo=0.3, hi=0.9)
        rect(im, cx - 5, 15, cx + 5, 17, "#6a1e3a")
        _eyes(im, ((cx - 2, 16), (cx + 2, 16)), "#ffe080")
        rect(im, cx - 6, 11, cx + 6, 13, "#7a3a18")
    line(im, 34, 18, 38, 34, "#a0a8b0")
    return outline(im)


def scrap_golem():
    im = new(40, 40)
    ball(im, 20, 26, 13, 12, "stone", lo=0.15, hi=0.75)
    ball(im, 20, 10, 7, 6, "stone", lo=0.25, hi=0.85)
    for (x, y) in ((12, 22), (26, 28), (18, 32)):
        rect(im, x, y, x + 4, y + 3, "#8a4a28")
    _eyes(im, ((17, 10), (18, 10), (22, 10), (23, 10)), "#ffce50")
    ball(im, 5, 28, 4, 6, "stone", lo=0.2, hi=0.7)
    ball(im, 35, 28, 4, 6, "stone", lo=0.2, hi=0.7)
    return outline(im)


def thorn_wolves():
    im = new(40, 40)
    for (cx, cy, s) in ((14, 26, 1.0), (27, 30, 0.9)):
        ball(im, cx, cy, 9 * s, 5.5 * s, "bean", lo=0.1, hi=0.55)
        ball(im, cx + 9 * s, cy - 5 * s, 4.5 * s, 3.8 * s, "bean", lo=0.15, hi=0.6)
        line(im, cx + 9 * s, cy - 9 * s, cx + 7 * s, cy - 13 * s, R["bean"][1])
        _eyes(im, ((cx + 10 * s, cy - 6 * s),), "#ffe080")
        for k in range(4):
            put(im, cx - 6 * s + k * 4 * s, cy - 6 * s, "#d0e090")
    return outline(im)


def sand_wraiths():
    im = new(40, 40)
    for (cx, s) in ((13, 0.9), (27, 1.0)):
        for y in range(8, 38):
            half = (6 + math.sin(y * 0.4) * 1.5) * s * (1 - max(0, y - 28) / 14)
            for x in range(int(cx - half), int(cx + half) + 1):
                put(im, x, y, P.ramp_d("dust", 0.75 - (y - 8) / 50 - (x - cx) / 40, x, y))
        _eyes(im, ((cx - 2, 14), (cx + 2, 14)), "#40d0ff")
    im = outline(im)
    return im


def locust_swarm():
    im = new(40, 40)
    import random
    rnd = random.Random(3)
    for _ in range(8):
        x, y = rnd.randint(7, 32), rnd.randint(7, 32)
        ball(im, x, y, 4.2, 2.4, "bean", lo=0.25, hi=0.85)
        for k in range(4):  # wings
            put(im, x - 3 + k, y - 3 - k // 2, "#e0f0c0")
            put(im, x - 2 + k, y - 4 - k // 2, "#c0d8a0")
        put(im, x + 3, y - 1, "#ff4a3a")
    return outline(im)


def iron_raiders():
    im = new(40, 40)
    for (cx, s) in ((12, 0.95), (28, 1.0)):
        ball(im, cx, 29, 6.5 * s, 8.5 * s, "stone", lo=0.2, hi=0.7)
        ball(im, cx, 15, 5.5 * s, 5.5 * s, "stone", lo=0.4, hi=0.95)
        rect(im, cx - 4, 15, cx + 4, 16, "#1e1a24")
        _eyes(im, ((cx - 2, 15), (cx + 2, 15)), "#ff6a3a")
        line(im, cx, 9, cx, 6, "#c84a3e")
    rect(im, 36, 12, 37, 36, R["wood"][3])
    for y in range(12, 20):
        line(im, 33, y, 36, y, "#a0a8b0")
    return outline(im)


def mire_hag():
    im = new(40, 40)
    for y in range(14, 39):
        half = 5 + (y - 14) * 0.5
        for x in range(int(20 - half), int(20 + half) + 1):
            put(im, x, y, P.ramp_d("melon", 0.15 + (0.3 - (x - 20) / 60), x, y))
    ball(im, 20, 12, 6, 6, "melon", lo=0.3, hi=0.8)
    for k in range(9):
        put(im, 14 + k * 1.5, 7 + (k % 3), "#3a3a2a")
    _eyes(im, ((18, 12), (22, 12)), "#ffe080")
    line(im, 20, 14, 21, 17, "#2a4a20")
    rect(im, 33, 8, 34, 38, R["wood"][2])
    ball(im, 33, 7, 3, 3, "berry", lo=0.3, hi=0.95)
    im = outline(im)
    glow(im, 33, 7, 7, "#b0f080", 0.3)
    return im


def dust_king():
    im = new(40, 40)
    for y in range(14, 40):
        half = 7 + (y - 14) * 0.55
        for x in range(int(20 - half), int(20 + half) + 1):
            put(im, x, y, P.ramp_d("cape", 0.2 + 0.4 * (0.6 - (x - 20) / 40), x, y))
    ball(im, 20, 11, 7, 7, "dust", lo=0.2, hi=0.75)
    for k in range(5):  # crown
        rect(im, 14 + k * 3, 2 + (k % 2) * 2, 15 + k * 3, 6, R["gold"][4])
    rect(im, 13, 5, 27, 6, R["gold"][3])
    _eyes(im, ((17, 11), (18, 11), (22, 11), (23, 11)), "#ff3a2a")
    rect(im, 4, 10, 5, 38, R["gold"][3])
    ball(im, 4.5, 9, 3, 3, "glow", lo=0.4, hi=1.0)
    im = outline(im)
    glow(im, 20, 11, 12, "#ff6a3a", 0.25)
    return im


UNITS = {f.__name__: f for f in (straw_guard, pumpkin_brute, moon_witch, crow_archer, frost_sentinel, storm_shaman)}
ENEMIES = {f.__name__: f for f in (dust_rats, rust_bandits, scrap_golem, thorn_wolves, sand_wraiths, locust_swarm,
                                    iron_raiders, mire_hag, dust_king)}


def sprites():
    from .crops_hd import ramps
    ramps()
    s = {}
    for k, f in UNITS.items():
        s["unit_" + k] = f()
    for k, f in ENEMIES.items():
        s["enemy_" + k] = f()
    return s
