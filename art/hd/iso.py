"""Isometric ground for the game: 48 x 24 px diamonds (72 x 36 pt in game,
shipped @2x). +x runs to the lower right, +y to the lower left, so a
tile's upper-right edge faces y-1 (N), lower-right faces x+1 (E),
lower-left faces y+1 (S) and upper-left faces x-1 (W). Sun from the
upper left: back edges get a lit rim, front edges a darker side."""
import random

from .draw import ball, line, new, outline, put, rect
from . import palette as P

TW, TH = 48, 24


def inside(x, y, inset=0.0):
    """Pixel (x, y) lies in the diamond, shrunk by `inset` px."""
    u = abs(x + 0.5 - TW / 2) / (TW / 2) + abs(y + 0.5 - TH / 2) / (TH / 2)
    return u <= 1 - inset / (TH / 2)


def edge_dist(x, y):
    """Distance (in px, vertical) from the pixel to each diamond edge:
    N = upper right, E = lower right, S = lower left, W = upper left."""
    cx, cy = x + 0.5 - TW / 2, y + 0.5 - TH / 2
    a = cx / 2  # x scaled to the 2:1 slope
    return {
        "N": TH / 2 + cy - a,   # 0 on the upper-right edge
        "W": TH / 2 + cy + a,
        "E": TH / 2 - cy - a,
        "S": TH / 2 - cy + a,
    }


def _noise(x, y, seed, scale=8):
    return P.fbm(x, y, seed, scale, 2)


def tile_grass(seed, flowers=0):
    R = P.RAMPS
    g = R["grass"]
    im = new(TW, TH)
    for y in range(TH):
        for x in range(TW):
            if inside(x, y):
                n = _noise(x, y, seed, 10)
                put(im, x, y, P.ramp_d("grass", 0.44 + n * 0.22, x, y, 0.9))
    rnd = random.Random(seed)
    for _ in range(18):
        x, y = rnd.randrange(TW), rnd.randrange(TH)
        if not inside(x, y, 2):
            continue
        hi = rnd.random() < 0.55
        put(im, x, y + 1, g[2] if hi else g[1])
        put(im, x, y, g[4] if hi else g[3])
        put(im, x - 1, y - 1, g[4] if hi else g[3])
        put(im, x + 1, y - 1, g[5] if hi else g[3])
    for _ in range(flowers):
        x, y = rnd.randrange(10, TW - 10), rnd.randrange(6, TH - 6)
        petal = rnd.choice(("#f2c8cc", "#f2e6a0", "#f4f0e6", "#c8b8e0"))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(im, x + dx, y + dy, petal)
        put(im, x, y, "#e8c050")
    return im


def tile_dust(seed):
    R = P.RAMPS
    im = new(TW, TH)
    for y in range(TH):
        for x in range(TW):
            if inside(x, y):
                n = _noise(x, y, seed, 12)
                put(im, x, y, P.ramp_d("dust", 0.5 + n * 0.14, x, y, 0.6))
    rnd = random.Random(seed)
    for _ in range(1 + seed % 2):
        x, y = rnd.randrange(14, TW - 14), rnd.randrange(7, TH - 7)
        put(im, x + 1, y + 2, R["dust"][1])
        ball(im, x, y, 1.8, 1.3, "dust", lo=0.35, hi=1.0)
    return im


def tile_grass_edge(mask, grass, dust):
    """Grass diamond whose sides facing dust are a raised turf: the top
    shrinks back from those edges, the front sides (E, S) show a soil
    lip, the back sides (N, W) a lit rim. Bits: 1=N 2=E 4=S 8=W green."""
    R = P.RAMPS
    g, s = R["grass"], R["soil"]
    im = dust.copy()
    open_sides = [k for k, bit in (("N", 1), ("E", 2), ("S", 4), ("W", 8)) if not mask & bit]
    for y in range(TH):
        for x in range(TW):
            if not inside(x, y):
                continue
            d = edge_dist(x, y)
            # ragged inset along open sides
            top = True
            lip = False
            rim = False
            for k in open_sides:
                jag = 1.6 + P.noise2(x, y, ord(k), 3) * 1.2
                if k in ("E", "S"):
                    if d[k] < jag:
                        top = False
                    elif d[k] < jag + 2.2:
                        lip = True
                else:
                    if d[k] < jag * 0.7:
                        top = False
                    elif d[k] < jag * 0.7 + 1.2:
                        rim = True
            if not top:
                continue
            c = grass.getpixel((x, y))
            if lip:
                c = s[2] if P.dither(x, y, 0.5) else s[3]
            elif rim:
                c = g[6] if P.dither(x, y, 0.6) else g[5]
            put(im, x, y, c)
    # turf casts a little shadow on the dust in front of it
    for y in range(TH):
        for x in range(TW):
            if inside(x, y) and im.getpixel((x, y)) == dust.getpixel((x, y)):
                d = edge_dist(x, y)
                for k in ("E", "S"):
                    if k in open_sides and 0.9 < d[k] < 2.2:
                        put(im, x, y, R["dust"][1])
    return im


def tile_bed(seed=7):
    """A furrowed soil mound on trodden earth; beds side by side make a field."""
    R = P.RAMPS
    s = R["soil"]
    im = new(TW, TH)
    for y in range(TH):
        for x in range(TW):
            if not inside(x, y):
                continue
            put(im, x, y, P.ramp_d("soil", 0.18 + _noise(x, y, seed, 6) * 0.1, x, y))
    for y in range(TH):
        for x in range(TW):
            if not inside(x, y, 2.2):
                continue
            d = edge_dist(x, y)
            if min(d["E"], d["S"]) < 4.2:   # front faces of the mound
                t = 0.24 if d["E"] < d["S"] else 0.34
            elif min(d["N"], d["W"]) < 3.4:  # lit top lip
                t = 0.8
            else:
                # furrows run along +x (parallel to the N edge)
                f = int(d["N"] * 0.9 + P.noise2(x, y, seed, 3) * 0.7) % 3
                t = 0.72 if f == 0 else 0.6 if f == 1 else 0.4
                if P.hash01(x, y, seed) < 0.06:
                    t += 0.16
            put(im, x, y - 1, P.ramp_d("soil", t, x, y))
    return im


def cursor():
    """Gold brackets on the diamond's four corners."""
    im = new(TW, TH)
    gold, dark = "#ffce50", "#8a5a18"
    for k in range(7):
        for (x, y) in ((1 + k * 2, TH // 2 - k), (1 + k * 2, TH // 2 - 1 + k),
                       (TW - 2 - k * 2, TH // 2 - k), (TW - 2 - k * 2, TH // 2 - 1 + k)):
            put(im, x, y, gold)
            put(im, x + (1 if x < TW / 2 else -1), y, gold)
    for k in range(7):
        for (x, y) in ((TW // 2 - 1 - k * 2, k), (TW // 2 + k * 2, k),
                       (TW // 2 - 1 - k * 2, TH - 1 - k), (TW // 2 + k * 2, TH - 1 - k)):
            put(im, x, y, gold)
            put(im, x + (1 if x >= TW / 2 else -1), y, gold)
    outline(im, dark)
    return im


def fence_edge(along_x):
    """One tile edge of fence: 24 px across, rails rising 12 px, posts at
    both ends. along_x: the rail runs "\\" (upper left to lower right)."""
    R = P.RAMPS
    wd = R["wood"]
    w, h = TW // 2 + 2, TH // 2 + 20
    im = new(w, h)
    base = h - 1
    # endpoints: lower end at the bottom row, upper end 12 px higher
    lo_x, hi_x = (w - 2, 1) if along_x else (1, w - 2)
    for (px, py) in ((hi_x, base - TH // 2), (lo_x, base)):
        rect(im, px - 1, py - 15, px + 1, py, wd[3])
        put(im, px - 1, py - 15, wd[5])
        rect(im, px - 1, py - 14, px - 1, py, wd[4])
    for z, c_hi, c_lo in ((6, wd[4], wd[2]), (12, wd[5], wd[3])):
        line(im, hi_x, base - TH // 2 - z, lo_x, base - z, c_hi)
        line(im, hi_x, base - TH // 2 - z + 1, lo_x, base - z + 1, c_lo)
    outline(im)
    return im


def crop_fit(im):
    """Trim an hd crop to its drawing so it stands on the bed by its base."""
    bb = im.getbbox()
    if not bb:
        return im
    return im.crop((0, 0, im.width, bb[3]))
