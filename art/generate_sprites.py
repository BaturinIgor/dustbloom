#!/usr/bin/env python3
"""Generates DUSTBLOOM pixel art.

Every sprite is drawn pixel by pixel from the palette in docs/style-guide.md,
so the art is reproducible and easy to tweak. Output:

  client/Dustbloom/Assets.xcassets/<name>.imageset/<name>.png  (1x pixels)
  art/preview.png   phone-screen mockup (what the game screen looks like)
  art/sheet.png     every sprite side by side

Run from the repo root:  python3 art/generate_sprites.py
Needs Pillow (pip install pillow).
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "client", "Dustbloom", "Assets.xcassets")
T = 16          # tile size in pixels
CW, CH = 16, 24  # crop sprite canvas (taller than a tile, base sits on the bed)

# ------------------------------------------------------------------ palette
P = {
    "ink": "#24161a",
    # wasteland: cool ash-lilac, low contrast, so the living farm pops
    "d0": "#433c4f", "d1": "#544c60", "d2": "#655d71", "d3": "#776f82",
    "d4": "#8b8395", "d5": "#a49cab", "d6": "#c2bbc6",
    # living soil
    "s0": "#2a1712", "s1": "#40241a", "s2": "#583423", "s3": "#71462d",
    "s4": "#8c5c3a", "s5": "#a9774c",
    # greens (living grass)
    "g0": "#173a2a", "g1": "#21573a", "g2": "#2f7a3e", "g3": "#4c9e3f",
    "g4": "#7cc24a", "g5": "#b6e46a",
    # gold / wheat
    "y0": "#6b3f12", "y1": "#a8661a", "y2": "#dc9a2c", "y3": "#f6c752",
    "y4": "#ffe590", "y5": "#fff6d0",
    # ember pumpkin
    "o0": "#5e1f12", "o1": "#93361a", "o2": "#c95a22", "o3": "#ee8430",
    "o4": "#ffae55", "o5": "#ffd9a0",
    # moon (rare, magic)
    "m0": "#1a3550", "m1": "#265f7a", "m2": "#3d9aa6", "m3": "#73d3c8",
    "m4": "#b8f5e4", "m5": "#f0fff8",
    # crimson accents, flowers
    "r1": "#9c2a4a", "r2": "#d8466a", "r3": "#ff8fa8",
    # wood
    "w0": "#3a2418", "w1": "#5a3824", "w2": "#7d5232", "w3": "#a2703f", "w4": "#c99a5c",
    # cloth (scarecrow)
    "c1": "#7a2f3a", "c2": "#a9434c", "c3": "#d36a62",
    "white": "#fff7e6",
}


def rgba(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else (*c, a)
    h = P[c].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def new(w=T, h=T):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, c, a=255):
    x, y = int(x), int(y)
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), rgba(c, a))


def get(im, x, y):
    if 0 <= x < im.width and 0 <= y < im.height:
        return im.getpixel((x, y))
    return (0, 0, 0, 0)


def blend(im, x, y, c, a):
    """Alpha-blend colour c over the pixel (keeps destination alpha)."""
    x, y = int(x), int(y)
    if not (0 <= x < im.width and 0 <= y < im.height):
        return
    r, g, b, da = im.getpixel((x, y))
    cr, cg, cb, _ = rgba(c)
    t = a / 255
    if da == 0:
        im.putpixel((x, y), (cr, cg, cb, a))
    else:
        im.putpixel((x, y), (round(r + (cr - r) * t), round(g + (cg - g) * t), round(b + (cb - b) * t), da))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        put(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y, t):
    """Ordered dither: True if a pixel at threshold t (0..1) is 'on'."""
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


def torus_noise(x, y, seed, size=T):
    """Smooth noise that tiles seamlessly over size x size."""
    rnd = random.Random(seed)
    v = 0.0
    for _ in range(4):
        fx, fy = rnd.choice((1, 1, 2)), rnd.choice((1, 1, 2))
        px, py = rnd.random() * 6.283, rnd.random() * 6.283
        v += math.sin(6.283 * fx * x / size + px) * math.sin(6.283 * fy * y / size + py)
    return v / 4  # about -1..1


def dark_outline(im, strength=0.45, only_below=False):
    """Selective outline: each edge pixel takes a darkened, purple-shifted
    version of its neighbour, which reads richer than a flat black line."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3]:
                continue
            best = None
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                n = get(src, x + dx, y + dy)
                if n[3] > 200:
                    best = n
                    break
            if best:
                r, g, b, _ = best
                k = strength
                im.putpixel((x, y), (int(r * k + 22 * (1 - k) * 0.4), int(g * k * 0.85), int(b * k + 30 * (1 - k) * 0.4), 255))
    return im


def shadow(im, cx, cy, rx, ry, a=70):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1 and get(im, x, y)[3] == 0:
                put(im, x, y, "ink", a if d < 0.55 else a // 2)


def ball(im, cx, cy, rx, ry, ramp, light=(-0.6, -0.8), rim=None):
    """Shaded ellipse. ramp: 6 colour names dark..light."""
    lx, ly = light
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d > 1:
                continue
            nz = math.sqrt(max(0, 1 - d))
            lum = (-lx * -dx + -ly * -dy) * 0.5 + nz * 0.6  # lambert-ish
            lum = lx * dx * -0.9 + ly * dy * -0.9 + nz * 0.55
            t = max(0, min(0.999, (lum + 0.35) / 1.25))
            idx = int(t * len(ramp))
            # dither between bands for a smooth, expensive gradient
            frac = t * len(ramp) - idx
            if idx < len(ramp) - 1 and dither(x, y, frac * 0.6):
                idx += 1
            put(im, x, y, ramp[idx])
            if rim and d > 0.78 and dx > 0.25 and dy > -0.2:
                put(im, x, y, rim)


# ------------------------------------------------------------------ ground
def tile_dust(seed):
    rnd = random.Random(seed)
    im = new()
    for y in range(T):
        for x in range(T):
            n = torus_noise(x, y, seed * 31 + 7)
            t = (n + 1) / 2
            c = "d3"
            if t > 0.62:
                c = "d4" if dither(x, y, min(1, (t - 0.62) * 4)) else "d3"
            elif t < 0.35:
                c = "d2" if dither(x, y, min(1, (0.35 - t) * 4)) else "d3"
            put(im, x, y, c)
    # hairline cracks
    for _ in range(rnd.randint(0, 2)):
        x, y = rnd.randint(2, 11), rnd.randint(2, 11)
        for _ in range(rnd.randint(3, 5)):
            put(im, x, y, "d1")
            put(im, x, y + 1, "d4")
            x += 1
            y += rnd.choice((0, 0, 1, -1))
    # pebbles: light top, dark bottom
    for _ in range(rnd.randint(1, 2)):
        px, py = rnd.randint(1, 13), rnd.randint(1, 13)
        put(im, px, py, "d5")
        put(im, px + 1, py, "d4")
        put(im, px, py + 1, "d2")
        put(im, px + 1, py + 1, "d1")
    # dry grass tuft
    if rnd.random() < 0.35:
        tx, ty = rnd.randint(2, 12), rnd.randint(5, 13)
        for k, h in enumerate((2, 3, 2)):
            for j in range(h):
                put(im, tx + k, ty - j, "d5" if j == h - 1 else "d4")
        put(im, tx, ty + 1, "d1")
        put(im, tx + 1, ty + 1, "d1")
        put(im, tx + 2, ty + 1, "d1")
    return im


def tile_grass(seed, flowers=0):
    rnd = random.Random(seed)
    im = new()
    for y in range(T):
        for x in range(T):
            t = (torus_noise(x, y, seed * 17 + 3) + 1) / 2
            c = "g2"
            if t > 0.6:
                c = "g3" if dither(x, y, min(1, (t - 0.6) * 3.5)) else "g2"
            elif t < 0.3:
                c = "g1" if dither(x, y, min(1, (0.3 - t) * 3.5)) else "g2"
            put(im, x, y, c)
    # blades: little lit 'v' shapes with a shadow foot
    for _ in range(6):
        x, y = rnd.randint(0, 15), rnd.randint(1, 15)
        put(im, x, y, "g4")
        put(im, x + 1, y - 1, "g5" if rnd.random() < 0.3 else "g4")
        put(im, x + 1, y + 1, "g1")
    for _ in range(flowers):
        x, y = rnd.randint(2, 13), rnd.randint(2, 13)
        petal = rnd.choice(("y4", "white", "r3"))
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            put(im, x + dx, y + dy, petal)
        put(im, x, y, "y2" if petal != "y4" else "o3")
        put(im, x, y + 2, "g1")
    return im


def edge_depth(i, seed):
    """Ragged edge depth for position i along a side (1..3)."""
    return 1 + int((math.sin(i * 1.7 + seed) + math.sin(i * 0.6 + seed * 2)) * 0.6 + 1.2) % 3


def tile_grass_edge(mask, base_dust, grass):
    """Grass tile whose sides facing dust (bit not set) are carved into a
    ragged, shaded edge. Bits: 1=N 2=E 4=S 8=W neighbour is green."""
    im = base_dust.copy()
    carve = [[False] * T for _ in range(T)]
    for i in range(T):
        if not mask & 1:
            for j in range(edge_depth(i, 1)):
                carve[j][i] = True
        if not mask & 4:
            for j in range(edge_depth(i, 3)):
                carve[T - 1 - j][i] = True
        if not mask & 8:
            for j in range(edge_depth(i, 5)):
                carve[i][j] = True
        if not mask & 2:
            for j in range(edge_depth(i, 7)):
                carve[i][T - 1 - j] = True
    for y in range(T):
        for x in range(T):
            if not carve[y][x]:
                im.putpixel((x, y), grass.getpixel((x, y)))
    # edge shading: lit rim on top edges, dark lip where grass meets dust below
    for y in range(T):
        for x in range(T):
            if carve[y][x]:
                continue
            if y + 1 < T and carve[y + 1][x]:
                put(im, x, y, "g1")
                put(im, x, y + 1, "d1")  # grass casts a shadow on dust
            elif y > 0 and carve[y - 1][x]:
                put(im, x, y, "g4")
            elif (x > 0 and carve[y][x - 1]) or (x + 1 < T and carve[y][x + 1]):
                put(im, x, y, "g1" if (x + y) % 2 else "g2")
    # blades poking onto the dust
    for y in range(T):
        for x in range(T):
            if carve[y][x] and y + 1 < T and not carve[y + 1][x] and (x * 7 + y) % 5 == 0:
                put(im, x, y, "g3")
    return im


def tile_bed(grass):
    """A raised soil bed sitting on grass (Hay Day-like plots read well on a phone)."""
    im = grass.copy()
    x0, y0, x1, y1 = 1, 1, 14, 14
    # body
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            corner = (x in (x0, x1)) and (y in (y0, y1))
            if corner:
                continue
            put(im, x, y, "s2")
    # top face with furrows (lit ridge, groove)
    for y in range(y0 + 1, y1 - 2):
        for x in range(x0 + 1, x1):
            c = "s3"
            if (y - y0) % 3 == 0:
                c = "s1"
            elif (y - y0) % 3 == 1:
                c = "s4"
            put(im, x, y, c)
    # crumbs
    rnd = random.Random(5)
    for _ in range(6):
        put(im, rnd.randint(x0 + 2, x1 - 2), rnd.randint(y0 + 2, y1 - 4), rnd.choice(("s5", "s1")))
    # front face (depth) and rim light
    for x in range(x0 + 1, x1):
        put(im, x, y1 - 2, "s2")
        put(im, x, y1 - 1, "s1")
        put(im, x, y1, "s0")
        put(im, x, y0, "s4")
    for y in range(y0 + 1, y1):
        put(im, x0, y, "s1")
        put(im, x1, y, "s0")
    put(im, x0 + 1, y0 + 1, "s5")
    # contact shadow on the grass
    for x in range(x0 + 1, x1 + 1):
        put(im, x, y1 + 1, "g0")
    return im


# ------------------------------------------------------------------ crops (16x24)
BASE = 20  # crop base row inside the 24 px canvas (bed top face)


def seed_stage(seed_col):
    im = new(CW, CH)
    # a little heaped mound with the seed on top
    for x in range(4, 12):
        put(im, x, BASE, "s1")
    for x in range(5, 11):
        put(im, x, BASE - 1, "s4" if x < 8 else "s3")
    for x in range(6, 10):
        put(im, x, BASE - 2, "s5" if x < 8 else "s4")
    put(im, 7, BASE - 3, seed_col)
    put(im, 8, BASE - 3, seed_col)
    put(im, 7, BASE - 4, "white")
    put(im, 8, BASE - 4, seed_col)
    return dark_outline(im)


def sprout(leaf_dark, leaf, leaf_light):
    im = new(CW, CH)
    shadow(im, 8, BASE, 4, 1.2)
    for y in range(BASE - 4, BASE + 1):
        put(im, 8, y, leaf_dark)
    # two cupped leaves
    for x, y, c in ((7, BASE - 5, leaf), (6, BASE - 6, leaf), (5, BASE - 6, leaf_light), (4, BASE - 7, leaf_light),
                    (9, BASE - 5, leaf), (10, BASE - 6, leaf), (11, BASE - 6, leaf), (12, BASE - 7, leaf_light),
                    (6, BASE - 5, leaf_dark), (10, BASE - 5, leaf_dark), (11, BASE - 7, leaf_light), (5, BASE - 7, leaf)):
        put(im, x, y, c)
    return dark_outline(im)


def wheat(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 6, 1.4)
    if stage == 2:
        stalks = [(4, 9), (7, 11), (10, 10), (12, 8)]
        for sx, h in stalks:
            for j in range(h):
                put(im, sx + (1 if j > h * 0.7 else 0), BASE - j, "g3" if j % 3 else "g2")
            put(im, sx - 1, BASE - h // 2, "g4")
            put(im, sx + 2, BASE - h // 2 - 2, "g2")
            put(im, sx + 1, BASE - h, "g5")
        return dark_outline(im)
    stalks = [(3, 13, -1), (6, 15, 0), (9, 14, 1), (12, 12, 1)]
    for sx, h, lean in stalks:
        for j in range(h - 5):
            x = sx + (lean if j > h * 0.5 else 0)
            put(im, x, BASE - j, "y1" if j < 3 else "y2")
        # plump grain head: alternating kernels with highlight side
        hx = sx + lean
        top = BASE - h
        for k in range(6):
            y = top + k
            put(im, hx, y, "y3" if k % 2 else "y4")
            put(im, hx - 1, y + (k % 2), "y2" if k > 1 else "y3")
            put(im, hx + 1, y + 1 - (k % 2), "y3" if k < 4 else "y2")
        put(im, hx, top - 1, "y5")
        put(im, hx - 1, top - 2, "y4")  # awn
        put(im, hx + 1, top - 3, "y4")
    # a leaf crossing the stalks
    for i, (x, y) in enumerate(((5, BASE - 3), (6, BASE - 4), (7, BASE - 4), (8, BASE - 5))):
        put(im, x, y, "g3" if i < 3 else "g4")
    return dark_outline(im)


def leaf(im, cx, cy, d, ramp=("g1", "g2", "g3", "g4")):
    """Broad leaf, d = -1 left / 1 right."""
    pts = [(0, 0), (1, 0), (2, 0), (1, -1), (2, -1), (3, -1), (0, 1), (1, 1), (2, 1), (3, 0), (4, -1), (3, -2)]
    for i, (px, py) in enumerate(pts):
        c = ramp[2] if py < 0 else ramp[1]
        if px == 4 or (px == 3 and py == -2):
            c = ramp[3]
        put(im, cx + px * d, cy + py, c)
    for px in range(0, 4):  # vein
        put(im, cx + px * d, cy, ramp[0] if px < 2 else ramp[1])


def pumpkin(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 7, 1.6)
    # vine
    for x in range(2, 14):
        put(im, x, BASE - (1 if 4 < x < 11 else 0), "g1")
    if stage == 2:
        leaf(im, 3, BASE - 4, 1)
        leaf(im, 13, BASE - 5, -1)
        leaf(im, 7, BASE - 8, 1)
        ball(im, 8.5, BASE - 2.5, 3, 2.4, ("g0", "g1", "g2", "g3", "g4", "g5"))
        put(im, 9, BASE - 5, "g1")
        return dark_outline(im)
    leaf(im, 1, BASE - 3, 1)
    leaf(im, 14, BASE - 4, -1)
    ball(im, 8, BASE - 5, 6.6, 5.4, ("o0", "o1", "o2", "o3", "o4", "o5"))
    # ribs: dark grooves following the curvature
    for rx in (5, 8, 11):
        for y in range(BASE - 9, BASE):
            off = 0 if abs(y - (BASE - 5)) < 3 else (1 if rx < 8 else -1 if rx > 8 else 0)
            if get(im, rx + off, y)[3]:
                put(im, rx + off, y, "o1" if rx != 8 else "o2")
    # specular highlight
    put(im, 4, BASE - 8, "o5")
    put(im, 5, BASE - 9, "o5")
    put(im, 4, BASE - 7, "o4")
    # stem with a curl
    rect(im, 7, BASE - 12, 8, BASE - 10, "g1")
    put(im, 7, BASE - 12, "g3")
    put(im, 9, BASE - 13, "g2")
    put(im, 10, BASE - 13, "g3")
    put(im, 10, BASE - 12, "g2")
    return dark_outline(im)


def turnip(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 5, 1.4)
    tall = 0 if stage == 2 else 2
    # leaf rosette: three broad leaves
    leaf(im, 7, BASE - 6 - tall, -1, ("g1", "g2", "g3", "g4"))
    leaf(im, 9, BASE - 7 - tall, 1, ("g1", "g2", "g3", "g5"))
    for j in range(5 + tall):
        put(im, 8, BASE - 3 - j, "g2" if j % 2 else "g3")
    put(im, 8, BASE - 8 - tall, "g4")
    if stage == 2:
        rect(im, 6, BASE - 2, 10, BASE - 1, "m2")
        put(im, 6, BASE - 2, "m3")
        put(im, 10, BASE - 1, "m1")
        return dark_outline(im)
    ball(im, 8, BASE - 3, 4.6, 3.6, ("m0", "m1", "m2", "m3", "m4", "m5"))
    put(im, 8, BASE + 1, "m1")  # root tip
    put(im, 6, BASE - 5, "m5")
    dark_outline(im)
    # moon glow: soft halo pixels around the bulb
    for x, y, a in ((2, BASE - 4, 120), (14, BASE - 2, 120), (3, BASE - 7, 70), (13, BASE - 6, 70), (12, BASE - 9, 160)):
        if get(im, x, y)[3] == 0:
            put(im, x, y, "m4", a)
    return im


# ------------------------------------------------------------------ props
def fence_h():
    im = new()
    for y in (6, 7, 10, 11):  # two rails
        for x in range(T):
            put(im, x, y, "w3" if y in (6, 10) else "w1")
    for px in (2, 12):
        rect(im, px, 3, px + 2, 14, "w2")
        put(im, px, 3, "w4")
        put(im, px + 1, 3, "w4")
        for y in range(4, 14):
            put(im, px + 2, y, "w1")
        put(im, px + 1, 8, "w0")  # nail
    for x in range(T):
        put(im, x, 15, "g0")
    return dark_outline(im)


def rock():
    im = new()
    ball(im, 8, 10, 5.5, 4, ("d0", "d1", "d2", "d4", "d5", "d6"))
    ball(im, 11.5, 12, 3, 2.2, ("d0", "d1", "d2", "d3", "d5", "d6"))
    put(im, 6, 8, "g3")  # moss
    put(im, 7, 7, "g4")
    shadow(im, 8.5, 14, 6.5, 1.3, 90)
    return dark_outline(im)


def dead_tree():
    im = new(T * 2, T * 2)
    w = im.width
    for y in range(12, 30):  # trunk
        for x in range(14, 18):
            put(im, x, y, "d1" if x == 17 else "d2" if x == 16 else "d3")
    for bx, by, ex, ey in ((15, 14, 7, 6), (16, 12, 24, 4), (15, 18, 6, 15), (17, 17, 26, 12), (10, 10, 9, 3), (22, 6, 27, 5)):
        line(im, bx, by, ex, ey, "d2")
        line(im, bx, by - 1, ex, ey - 1, "d4")
    shadow(im, 16, 30, 7, 1.5, 90)
    return dark_outline(im)


def scarecrow():
    """The game's hero unit, standing guard by the farm (16x32)."""
    im = new(T, T * 2)
    # pole
    for y in range(14, 31):
        put(im, 7, y, "w2")
        put(im, 8, y, "w1")
    # arms (crossbar) with straw hands
    for x in range(1, 15):
        put(im, x, 13, "w3")
        put(im, x, 14, "w1")
    for hx in (0, 15):
        put(im, hx, 12, "y4")
        put(im, hx, 14, "y3")
        put(im, hx, 13, "y3")
    # coat (patched crimson)
    for y in range(12, 22):
        half = 3 + (y - 12) // 3
        for x in range(8 - half, 8 + half):
            c = "c2" if x < 8 else "c1"
            if x == 8 - half:
                c = "c3"
            put(im, x, y, c)
    rect(im, 9, 16, 10, 17, "w3")  # patch
    put(im, 9, 16, "w4")
    for x in range(4, 12):  # belt of rope
        put(im, x, 18, "y2" if x % 2 else "y1")
    # straw spilling from cuffs and hem
    for x, y in ((4, 22), (6, 23), (9, 23), (11, 22), (5, 22), (10, 22)):
        put(im, x, y, "y3")
    # head: burlap sack with glowing ember eyes
    ball(im, 8, 8, 3.6, 3.4, ("y0", "y1", "y2", "y3", "y4", "y5"))
    put(im, 6, 8, "o4")
    put(im, 10, 8, "o4")
    put(im, 6, 9, "o2")
    put(im, 10, 9, "o2")
    for x in range(6, 11):
        put(im, x, 11, "y1" if x % 2 else "y0")  # stitched mouth
    # hat
    for x in range(3, 14):
        put(im, x, 5, "w1" if x > 9 else "w2")
    for y in range(1, 5):
        for x in range(5 + (1 if y == 1 else 0), 12 - (1 if y == 1 else 0)):
            put(im, x, y, "w2" if x < 9 else "w1")
    put(im, 6, 2, "w3")
    for x in range(5, 12):
        put(im, x, 4, "c2")  # hat band
    shadow(im, 8, 30.5, 6, 1.4, 90)
    return dark_outline(im)


def farmhouse():
    """48x48 farmhouse: crimson shingle roof, plank walls, glowing windows."""
    im = new(48, 48)
    # foundation stones
    for x in range(4, 44):
        put(im, x, 44, "d4" if (x // 3) % 2 else "d3")
        put(im, x, 45, "d2")
        put(im, x, 46, "d1")
    # plank walls
    for y in range(24, 44):
        for x in range(5, 43):
            c = "w3" if x < 24 else "w2"
            if (x - 5) % 5 == 0:
                c = "w1"
            elif (x - 5) % 5 == 1 and x < 24:
                c = "w4"
            put(im, x, y, c)
    for x in range(5, 43):  # shadow under the eaves
        put(im, x, 24, "w0")
        put(im, x, 25, "w1")
    # door
    rect(im, 20, 30, 28, 43, "w0")
    rect(im, 21, 31, 27, 43, "w1")
    for y in range(31, 44):
        put(im, 24, y, "w0")
    put(im, 26, 37, "y4")
    rect(im, 19, 29, 29, 29, "w4")
    # windows with warm light and a flower box
    for wx in (8, 32):
        rect(im, wx, 29, wx + 7, 36, "w0")
        for y in range(30, 36):
            for x in range(wx + 1, wx + 7):
                put(im, x, y, "y4" if y < 33 else "y3")
        put(im, wx + 1, 30, "y5")
        put(im, wx + 2, 30, "y5")
        for y in range(30, 36):
            put(im, wx + 4, y, "w0")
        for x in range(wx + 1, wx + 7):
            put(im, x, 33, "w0")
        rect(im, wx - 1, 37, wx + 8, 38, "w1")
        for x in range(wx, wx + 8, 2):
            put(im, x, 36, "r2" if (x // 2) % 2 else "y4")
            put(im, x + 1, 36, "g3")
    # roof: shingle rows, widening downwards
    for y in range(4, 25):
        half = 14 + (y - 4) * 9 // 20
        for x in range(24 - half, 24 + half):
            row = (y - 4) // 3
            shift = 2 if row % 2 else 0
            c = "c2" if x < 24 else "c1"
            if (y - 4) % 3 == 2:
                c = "r1" if x < 24 else "c1"
            elif (x + shift) % 4 == 0:
                c = "c1"
            elif (y - 4) % 3 == 0 and x < 24:
                c = "c3"
            put(im, x, y, c)
    for x in range(9, 39):  # ridge cap
        put(im, x, 3, "w2")
        put(im, x, 2, "w4" if x < 24 else "w3")
    # chimney
    rect(im, 33, 0, 37, 8, "d3")
    rect(im, 32, 0, 38, 1, "d4")
    for y in range(2, 9):
        put(im, 37, y, "d1")
        put(im, 33, y, "d4")
    dark_outline(im)
    return im


def windmill_tower():
    """32x48 stone and timber tower; the sails are a separate sprite that spins."""
    im = new(32, 48)
    for y in range(10, 46):
        half = 6 + (y - 10) * 6 // 36
        for x in range(16 - half, 16 + half):
            c = "d4" if x < 16 else "d3"
            if (y // 4 + x // 4) % 2 == 0 and (y % 4 == 0 or x % 4 == 0):
                c = "d2"
            if x == 16 - half:
                c = "d5"
            put(im, x, y, c)
    # timber cap
    for y in range(3, 11):
        half = 4 + (y - 3)
        for x in range(16 - half, 16 + half):
            put(im, x, y, "w2" if x < 16 else "w1")
            if y == 3 + (y % 2) and x < 16:
                put(im, x, y, "w3")
    rect(im, 13, 36, 18, 45, "w0")  # door
    rect(im, 14, 37, 17, 45, "w1")
    rect(im, 14, 20, 17, 24, "w0")  # window
    rect(im, 15, 21, 16, 23, "y3")
    rect(im, 14, 6, 17, 9, "w0")  # hub
    return dark_outline(im)


def windmill_sails():
    """40x40, four lattice sails around a hub; rotate this node in-game."""
    im = new(40, 40)
    c = 20
    for ang in range(4):
        a = ang * math.pi / 2 + math.pi / 4
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        for r in range(2, 19):
            x, y = c + dx * r, c + dy * r
            put(im, x, y, "w1")
            if r > 5:
                for w in range(1, 5):
                    sx, sy = x + px * w, y + py * w
                    put(im, sx, sy, "white" if w < 4 else "w3")
                    if r % 4 == 0:
                        put(im, sx, sy, "w2")
    rect(im, 18, 18, 21, 21, "w0")
    put(im, 19, 19, "w4")
    return dark_outline(im)


def pond(frame):
    """48x32 pond with shore, depth, lily pads, reeds and moving glints."""
    im = new(48, 32)
    cx, cy, rx, ry = 24, 16, 22, 13
    for y in range(32):
        for x in range(48):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d > 1:
                continue
            if d > 0.82:
                c = "s4" if y < cy else "s3"  # sandy shore
                if d > 0.93:
                    c = "s5" if y < cy else "s2"
            elif d > 0.62:
                c = "m2"
            elif d > 0.3:
                c = "m1" if dither(x, y, (0.62 - d) * 3) else "m2"
            else:
                c = "m0" if dither(x, y, (0.3 - d) * 4) else "m1"
            put(im, x, y, c)
    # shore shadow line on the water (top edge)
    for x in range(48):
        for y in range(32):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if 0.74 < d <= 0.82 and y < cy:
                put(im, x, y, "m1")
    # glints that move between frames
    off = 3 if frame else 0
    for gx, gy, n in ((12 + off, 12, 4), (26 - off, 19, 3), (32 + off, 10, 2), (18, 22 - (1 if frame else 0), 2)):
        for i in range(n):
            put(im, gx + i, gy, "m4" if i else "m5")
    # lily pads
    for lx, ly in ((30, 18), (14, 16)):
        for y in range(ly - 2, ly + 2):
            for x in range(lx - 3, lx + 3):
                if ((x + 0.5 - lx) / 3) ** 2 + ((y + 0.5 - ly) / 2) ** 2 <= 1 and not (x == lx and y < ly):
                    put(im, x, y, "g3" if y < ly else "g2")
    put(im, 31, 16, "r3")
    put(im, 32, 16, "r2")
    put(im, 31, 15, "white")
    # reeds
    for rx_, h in ((5, 9), (7, 12), (9, 8), (41, 10), (43, 7)):
        for j in range(h):
            put(im, rx_, 22 - j, "g2" if j < h - 3 else "g3")
        rect(im, rx_, 22 - h, rx_, 22 - h + 2, "w1")
    return dark_outline(im)


def stepping_stones():
    im = new()
    for sx, sy in ((3, 3), (9, 6), (4, 10), (10, 12)):
        ball(im, sx + 1.5, sy + 1, 2.4, 1.6, ("d1", "d2", "d3", "d4", "d5", "d6"))
        put(im, sx, sy + 3, "g0")
        put(im, sx + 2, sy + 3, "g0")
    return im


def firefly():
    im = new(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, y + 0.5 - 4)
            if d < 3.8:
                put(im, x, y, "y4", int(max(0, 110 - d * 30)))
    put(im, 3, 3, "y5")
    put(im, 4, 3, "white")
    put(im, 3, 4, "y4")
    put(im, 4, 4, "y5")
    return im


def mote():
    im = new(4, 4)
    put(im, 1, 1, "d6", 200)
    put(im, 2, 1, "d6", 120)
    put(im, 1, 2, "d6", 120)
    return im


def smoke():
    im = new(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, y + 0.5 - 4)
            if d < 3.6:
                put(im, x, y, "d6" if x + y < 7 else "d4", 210)
    return im


# ------------------------------------------------------------------ pixel font
GLYPHS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
}


def glyph(ch, fill=("y5", "y3"), edge="ink"):
    """7x10 glyph: 5x7 shape with a two-tone fill (light top, darker bottom),
    a 1 px outline and a 1 px drop shadow under the outline."""
    im = new(7, 10)
    for y, row in enumerate(GLYPHS[ch]):
        for x, bit in enumerate(row):
            if bit == "1":
                put(im, x + 1, y + 1, fill[0] if y < 3 else fill[1])
    shape = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if shape.getpixel((x, y))[3]:
                continue
            if edge and any(get(shape, x + dx, y + dy)[3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                put(im, x, y, edge)
    return im


def text_image(text, fill=("y5", "y3"), edge="ink"):
    """Glyphs share their outline column, so letters sit 1 px apart."""
    gl = [glyph(c, fill, edge) for c in text]
    w = sum(g.width - 1 for g in gl) + 1
    im = new(w, 10)
    x = 0
    for g in gl:
        im.alpha_composite(g, (x, 0))
        x += g.width - 1
    return im


# ------------------------------------------------------------------ pixel UI frames (pre-scaled x3)
def nine_slice(fill, light, shade, outline="ink", size=12, corner=4):
    im = new(size, size)
    for y in range(size):
        for x in range(size):
            cut = (x in (0, size - 1)) and (y in (0, size - 1))
            if cut:
                continue
            edge = x in (0, size - 1) or y in (0, size - 1)
            c = outline if edge else fill
            if not edge:
                if y == 1 or x == 1:
                    c = light
                if y == size - 2 or x == size - 2:
                    c = shade
                if y == size - 3 and 1 < x < size - 2:
                    c = shade
            put(im, x, y, c)
    put(im, 1, 1, outline)
    put(im, size - 2, 1, outline)
    put(im, 1, size - 2, outline)
    put(im, size - 2, size - 2, outline)
    return im


def ui_frames():
    parch = ("#f4e6c4", "#fff7e6", "#d9bf88")
    P["p0"], P["p1"], P["p2"] = parch
    P["ps0"], P["ps1"], P["ps2"] = "#e2cc9a", "#efdcb0", "#c4a670"
    return {
        "ui_panel": nine_slice("p0", "p1", "p2"),
        "ui_slot": nine_slice("ps0", "ps1", "ps2", outline="w1"),
        "ui_slot_selected": nine_slice("y3", "y5", "y1", outline="w0"),
    }


# ------------------------------------------------------------------ ui bits
def coin():
    im = new()
    ball(im, 8, 8, 6, 6, ("y0", "y1", "y2", "y3", "y4", "y5"))
    # embossed sprout (the logo) on the face
    for x, y in ((8, 11), (8, 10), (8, 9), (7, 8), (6, 7), (9, 8), (10, 7)):
        put(im, x, y, "y1")
    put(im, 5, 5, "y5")
    return dark_outline(im, 0.4)


def cursor():
    im = new()
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)):
        for i in range(4):
            put(im, cx + sx * i, cy, "white")
            put(im, cx, cy + sy * i, "white")
        put(im, cx + sx, cy + sy, "y4")
    return im


def sparkle():
    im = new(8, 8)
    for i in range(8):
        a = (60, 140, 255, 255, 255, 255, 140, 60)[i]
        put(im, 3, i, "y4", a)
        put(im, i, 3, "y4", a)
    put(im, 3, 3, "white")
    put(im, 2, 2, "y5", 120)
    put(im, 4, 4, "y5", 120)
    return im


# ------------------------------------------------------------------ output
def save_imageset(name, im):
    d = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": name + ".png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)


def write_app_icon(src):
    d = os.path.join(ASSETS, "AppIcon.appiconset")
    os.makedirs(d, exist_ok=True)
    Image.open(src).convert("RGB").resize((1024, 1024), Image.NEAREST).save(os.path.join(d, "AppIcon.png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)


def cast_shadow(im, base_y=None, shear=0.55, squash=0.45, alpha=80):
    """Bake a long evening shadow: the sprite's silhouette laid on the ground,
    sheared to the right (sun low on the left). Same canvas height, wider."""
    w, h = im.size
    base_y = h if base_y is None else base_y
    sh = int(base_y * squash)
    out = new(w + int(base_y * shear) + 2, h)
    for y in range(base_y):
        for x in range(w):
            if im.getpixel((x, y))[3] > 100:
                dist = base_y - y  # height above ground
                ny = base_y - 1 - int(dist * squash * 0.35)
                nx = x + int(dist * shear)
                if 0 <= ny < h and get(out, nx, ny)[3] == 0:
                    put(out, nx, ny, "ink", alpha)
                    put(out, nx + 1, ny, "ink", alpha)
    return out


def light_textures():
    """Smooth (non-pixel) overlays: warm sunset light and a vignette."""
    w, h = 64, 128
    light = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 4) / w, (y - 10) / h * 0.9)
            a = max(0.0, 1 - d * 1.05)
            light.putpixel((x, y), (255, 178, 96, int(150 * a * a)))
    vig = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            d = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            a = max(0.0, min(1.0, (d - 0.55) / 0.6))
            vig.putpixel((x, y), (22, 12, 30, int(200 * a)))
    return light, vig


def build_sprites():
    dust = [tile_dust(s) for s in (1, 2, 3)]
    grass = [tile_grass(11), tile_grass(12, flowers=1), tile_grass(13, flowers=2)]
    s = {}
    for i, im in enumerate(dust):
        s["tile_dust_%d" % i] = im
    for i, im in enumerate(grass):
        s["tile_grass_%d" % i] = im
    for mask in range(15):  # 15 = fully surrounded, uses tile_grass_N
        s["tile_grass_edge_%d" % mask] = tile_grass_edge(mask, dust[0], grass[0])
    s["tile_bed"] = tile_bed(grass[0])
    s["dustwheat_0"] = seed_stage("y3")
    s["dustwheat_1"] = sprout("g2", "g3", "g5")
    s["dustwheat_2"] = wheat(2)
    s["dustwheat_3"] = wheat(3)
    s["emberpumpkin_0"] = seed_stage("o4")
    s["emberpumpkin_1"] = sprout("g1", "g2", "g4")
    s["emberpumpkin_2"] = pumpkin(2)
    s["emberpumpkin_3"] = pumpkin(3)
    s["moonturnip_0"] = seed_stage("m4")
    s["moonturnip_1"] = sprout("m1", "m2", "m4")
    s["moonturnip_2"] = turnip(2)
    s["moonturnip_3"] = turnip(3)
    s["prop_fence"] = fence_h()
    s["prop_rock"] = rock()
    s["prop_dead_tree"] = dead_tree()
    s["prop_scarecrow"] = scarecrow()
    s["prop_house"] = farmhouse()
    s["prop_windmill"] = windmill_tower()
    s["prop_windmill_sails"] = windmill_sails()
    s["prop_pond_0"] = pond(0)
    s["prop_pond_1"] = pond(1)
    s["prop_stones"] = stepping_stones()
    for name in ("prop_house", "prop_windmill", "prop_scarecrow", "prop_dead_tree", "prop_rock"):
        s["shadow_" + name[5:]] = cast_shadow(s[name])
    s["fx_firefly"] = firefly()
    s["fx_mote"] = mote()
    s["fx_smoke"] = smoke()
    s["ui_coin"] = coin()
    s["ui_cursor"] = cursor()
    s["fx_sparkle"] = sparkle()
    for ch in GLYPHS:
        key = {"+": "plus"}.get(ch, ch)
        s["font_" + key] = glyph(ch, ("w0", "ink"), None)       # HUD: ink on parchment
        s["font_gold_" + key] = glyph(ch)                        # floating gains
    from units_art import land_sprites, stage1_sprites  # needs this module's helpers
    s.update(stage1_sprites())
    s.update(land_sprites())
    from crops_art import crop_sprites
    s.update(crop_sprites())
    from items_art import item_sprites
    s.update(item_sprites())
    return s


# ---- world layout shared with the client (FarmScene.swift, Layout)
# Offsets are relative to the start patch's top-left tile (config startTilled).
STRUCTURES = [
    # name, dx, dy (top-left tile), width, height in tiles
    ("prop_house", -1, -5, 3, 3),
    ("prop_windmill", 3, -5, 2, 3),
    ("prop_pond", 0, 4, 3, 2),
]
DECOR = [
    ("prop_stones", 0, -2),
    ("prop_stones", 0, -1),
    ("prop_scarecrow", -1, 2),
]


def life_sources(tilled, start, w, h):
    src = [row[:] for row in tilled]
    sx, sy = start
    for _, dx, dy, ww, hh in STRUCTURES:
        for y in range(sy + dy, sy + dy + hh):
            for x in range(sx + dx, sx + dx + ww):
                if 0 <= x < w and 0 <= y < h:
                    src[y][x] = True
    return src


def is_green(src, x, y, w, h):
    """Grass grows around beds and buildings: the farm brings life to the
    wasteland. Green when the nearest life source is within 2.3 tiles."""
    for yy in range(max(0, y - 2), min(h, y + 3)):
        for xx in range(max(0, x - 2), min(w, x + 3)):
            if src[yy][xx] and (xx - x) ** 2 + (yy - y) ** 2 <= 2.3 ** 2:
                return True
    return False


def ground_name(tilled, src, x, y, w, h):
    if 0 <= x < w and 0 <= y < h and tilled[y][x]:
        return "tile_bed"
    inside = 0 <= x < w and 0 <= y < h
    if not inside or not is_green(src, x, y, w, h):
        return "tile_dust_%d" % ((x * 7 + y * 13) % 3)

    def g(xx, yy):
        if not (0 <= xx < w and 0 <= yy < h):
            return False
        return is_green(src, xx, yy, w, h)
    mask = (1 if g(x, y - 1) else 0) | (2 if g(x + 1, y) else 0) | (4 if g(x, y + 1) else 0) | (8 if g(x - 1, y) else 0)
    if mask == 15:
        v = (x * 5 + y * 3) % 7
        return "tile_grass_%d" % (1 if v == 0 else 2 if v == 3 else 0)
    return "tile_grass_edge_%d" % mask


def nine_slice_draw(dst, tile, box, scale):
    """Draw a 12x12 nine-slice sprite into box (x0,y0,x1,y1) at pixel scale."""
    x0, y0, x1, y1 = box
    c = 4 * scale
    big = tile.resize((tile.width * scale, tile.height * scale), Image.NEAREST)
    W, H = x1 - x0, y1 - y0
    parts = {
        "tl": (0, 0, c, c), "tr": (big.width - c, 0, big.width, c),
        "bl": (0, big.height - c, c, big.height), "br": (big.width - c, big.height - c, big.width, big.height),
    }
    mid = big.crop((c, c, big.width - c, big.height - c)).resize((W - 2 * c, H - 2 * c), Image.NEAREST)
    top = big.crop((c, 0, big.width - c, c)).resize((W - 2 * c, c), Image.NEAREST)
    bot = big.crop((c, big.height - c, big.width - c, big.height)).resize((W - 2 * c, c), Image.NEAREST)
    lef = big.crop((0, c, c, big.height - c)).resize((c, H - 2 * c), Image.NEAREST)
    rig = big.crop((big.width - c, c, big.width, big.height - c)).resize((c, H - 2 * c), Image.NEAREST)
    dst.alpha_composite(mid, (x0 + c, y0 + c))
    dst.alpha_composite(top, (x0 + c, y0))
    dst.alpha_composite(bot, (x0 + c, y1 - c))
    dst.alpha_composite(lef, (x0, y0 + c))
    dst.alpha_composite(rig, (x1 - c, y0 + c))
    dst.alpha_composite(big.crop(parts["tl"]), (x0, y0))
    dst.alpha_composite(big.crop(parts["tr"]), (x1 - c, y0))
    dst.alpha_composite(big.crop(parts["bl"]), (x0, y1 - c))
    dst.alpha_composite(big.crop(parts["br"]), (x1 - c, y1 - c))


def render_preview(s, frames):
    """Phone-screen mockup: 390x844 pt at @2x, tiles 48 pt (16 px x3), same
    layout rules as the game."""
    W, H, PX, K = 390, 844, 3, 2
    fw, fh = 16, 16
    start = (6, 6)
    tilled = [[False] * fw for _ in range(fh)]
    for y in range(6, 10):
        for x in range(6, 10):
            tilled[y][x] = True
    src = life_sources(tilled, start, fw, fh)
    pad = 6  # decorative wasteland beyond the farm edge
    ww, wh = (fw + 2 * pad) * T, (fh + 2 * pad) * T
    world = Image.new("RGBA", (ww, wh))

    def at(tx, ty):  # tile -> world pixel
        return (tx + pad) * T, (ty + pad) * T

    for y in range(-pad, fh + pad):
        for x in range(-pad, fw + pad):
            world.alpha_composite(s[ground_name(tilled, src, x, y, fw, fh)], at(x, y))

    objects = []  # (sort_y, name, px, py)

    def obj(name, tx, ty, tw, th, ox=0, oy=0):
        im = s[name]
        bx, by = at(tx, ty)
        px = bx + (tw * T - im.width) // 2 + ox if name != "prop_house" else bx + ox
        py = by + th * T - im.height + oy
        objects.append((by + th * T, name, px, py))

    sx, sy = start
    for name, dx, dy, tw, th in STRUCTURES:
        n = name + ("_0" if name == "prop_pond" else "")
        obj(n, sx + dx, sy + dy, tw, th)
    for name, dx, dy in DECOR:
        h = s[name].height // T
        obj(name, sx + dx, sy + dy - (h - 1), 1, h)
    for name, x, y, th in (("prop_dead_tree", 3, 13, 2), ("prop_rock", 13, 12, 1), ("prop_rock", 2, 1, 1),
                           ("prop_dead_tree", 13, -1, 2), ("prop_rock", 4, 15, 1)):
        obj(name, x, y - (th - 1), 2 if th == 2 else 1, th)
    # fence pieces flanking the path
    for x in (sx - 2, sx - 1, sx + 1, sx + 2, sx + 3):
        obj("prop_fence", x, sy - 2, 1, 1, oy=-4)

    crops = {
        (6, 6): "dustwheat_3", (7, 6): "dustwheat_3", (8, 6): "dustwheat_2", (9, 6): "dustwheat_1",
        (6, 7): "emberpumpkin_3", (7, 7): "emberpumpkin_3", (8, 7): "emberpumpkin_2", (9, 7): "emberpumpkin_1",
        (6, 8): "moonturnip_3", (7, 8): "moonturnip_3", (8, 8): "moonturnip_2", (9, 8): "dustwheat_0",
        (6, 9): "moonturnip_1", (7, 9): "emberpumpkin_0",
    }
    for (x, y), name in crops.items():
        bx, by = at(x, y)
        objects.append((by + T - 0.5, name, bx, by + T - CH))

    # shadows first (on the ground), then objects back to front
    for sort_y, name, px, py in objects:
        key = "shadow_" + name[5:]
        if name.startswith("prop_") and key in s:
            world.alpha_composite(s[key], (px, py))
    for sort_y, name, px, py in sorted(objects, key=lambda o: o[0]):
        world.alpha_composite(s[name], (px, py))
        if name == "prop_windmill":
            sails = s["prop_windmill_sails"].rotate(12, resample=Image.NEAREST)
            world.alpha_composite(sails, (px + 16 - 20, py + 8 - 20))
        if name == "prop_house":
            for i, (ox, oy) in enumerate(((35, -6), (37, -12), (40, -19))):
                sm = s["fx_smoke"].copy()
                sm.putalpha(sm.getchannel("A").point(lambda a, i=i: int(a * (1 - i * 0.28))))
                world.alpha_composite(sm, (px + ox, py + oy))

    # life fx: fireflies over the grass, dust motes over the wasteland
    rnd = random.Random(9)
    for _ in range(140):
        tx, ty = rnd.randint(-pad, fw + pad - 1), rnd.randint(-pad, fh + pad - 1)
        inside = 0 <= tx < fw and 0 <= ty < fh
        px, py = at(tx, ty)
        px += rnd.randint(0, 12)
        py += rnd.randint(0, 12)
        if inside and is_green(src, tx, ty, fw, fh) and not tilled[ty][tx]:
            if rnd.random() < 0.35:
                world.alpha_composite(s["fx_firefly"], (px, py))
        elif rnd.random() < 0.5:
            world.alpha_composite(s["fx_mote"], (px, py))

    # sparkles on ripe crops + cursor on the one being harvested
    for (x, y) in ((6, 6), (7, 8)):
        bx, by = at(x, y)
        world.alpha_composite(s["fx_sparkle"], (bx + 10, by - 9))
    cbx, cby = at(7, 7)
    world.alpha_composite(s["ui_cursor"], (cbx, cby))

    # camera
    vw, vh = W // PX, H // PX
    cx, cy = at(8, 6)
    cx += 0
    cy += 8
    view = world.crop((cx - vw // 2, cy - vh // 2, cx - vw // 2 + vw, cy - vh // 2 + vh))
    screen = view.resize((vw * PX * K, vh * PX * K), Image.NEAREST)
    sw, sh = screen.size

    # lighting: the same overlays the game uses (fx_light additive, fx_vignette)
    light, vig = frames["fx_light"], frames["fx_vignette"]
    lt = light.resize((sw, sh), Image.BILINEAR)
    base = screen.convert("RGB")
    add = Image.new("RGB", (sw, sh))
    add.paste(lt.convert("RGB"), mask=lt.getchannel("A"))
    from PIL import ImageChops
    base = ImageChops.add(base, ImageChops.multiply(add, Image.new("RGB", (sw, sh), (170, 170, 170))))
    screen = base.convert("RGBA")
    screen.alpha_composite(vig.resize((sw, sh), Image.BILINEAR))

    # HUD: pixel panels and pixel font, the same assets HUDView.swift uses
    U = PX * K  # one art pixel on screen
    def pixtext(text, x, y, scale=U, ink=True):
        im = text_image(text, ("w0", "ink"), None) if ink else text_image(text)
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        screen.alpha_composite(im, (x, y))
        return im.width

    top = 54 * K
    # coin pill
    nine_slice_draw(screen, frames["ui_panel"], (16 * K, top, 16 * K + 120 * K, top + 42 * K), U)
    coin = s["ui_coin"].resize((16 * U // 2 * 1, 16 * U // 2), Image.NEAREST)
    coin = s["ui_coin"].resize((14 * K * 2, 14 * K * 2), Image.NEAREST)
    screen.alpha_composite(coin, (24 * K, top + 7 * K))
    pixtext("126", 52 * K, top + 6 * K, U)
    # level pill
    nine_slice_draw(screen, frames["ui_panel"], (144 * K, top, 144 * K + 92 * K, top + 42 * K), U)
    pixtext("LV3", 156 * K, top + 6 * K, U)

    # crop bar
    slot_w, slot_h, gap = 88 * K, 96 * K, 10 * K
    bw = 3 * slot_w + 2 * gap + 24 * K
    bh = slot_h + 24 * K
    bx, by = (sw - bw) // 2, sh - bh - 30 * K
    nine_slice_draw(screen, frames["ui_panel"], (bx, by, bx + bw, by + bh), U)
    for i, (cid, cost) in enumerate((("dustwheat", "2"), ("emberpumpkin", "8"), ("moonturnip", "20"))):
        x = bx + 12 * K + i * (slot_w + gap)
        y = by + 12 * K
        sel = i == 1
        lift = 4 * K if sel else 0
        nine_slice_draw(screen, frames["ui_slot_selected" if sel else "ui_slot"], (x, y - lift, x + slot_w, y + slot_h - lift), U)
        spr = s[cid + "_3"].crop((0, 4, CW, CH - 2))
        spr = spr.resize((spr.width * U, spr.height * U), Image.NEAREST)
        screen.alpha_composite(spr, (x + (slot_w - spr.width) // 2, y + 2 * K - lift))
        cw = 16 * K
        tw = (len(cost) * 6 + 1) * 2 * K
        tx = x + (slot_w - (cw + 3 * K + tw)) // 2
        ty = y + slot_h - 26 * K - lift
        screen.alpha_composite(s["ui_coin"].resize((cw, cw), Image.NEAREST), (tx, ty + 1 * K))
        pixtext(cost, tx + cw + 3 * K, ty, 2 * K)

    # floating +22 over the harvested pumpkin
    hx = (cbx - (cx - vw // 2)) * U - 2 * K
    hy = (cby - 20 - (cy - vh // 2)) * U
    pixtext("+22", hx, hy, 3 * K, ink=False)
    return screen


def main():
    os.makedirs(ASSETS, exist_ok=True)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    s = build_sprites()
    frames = ui_frames()
    light, vig = light_textures()
    frames["fx_light"], frames["fx_vignette"] = light, vig

    keep = set(s) | set(frames) | {"logo_wordmark"}
    for d in os.listdir(ASSETS):
        if d.endswith(".imageset") and d[:-9] not in keep:
            for f in os.listdir(os.path.join(ASSETS, d)):
                os.remove(os.path.join(ASSETS, d, f))
            os.rmdir(os.path.join(ASSETS, d))
    for name, im in s.items():
        save_imageset(name, im)
    for name in ("ui_panel", "ui_slot", "ui_slot_selected"):
        # pre-scaled x3 so SwiftUI nine-slice cap insets are 12 pt
        im = frames[name]
        save_imageset(name, im.resize((im.width * 3, im.height * 3), Image.NEAREST))
    save_imageset("fx_light", light)
    save_imageset("fx_vignette", vig)

    src = os.path.join(ROOT, "art", "source")
    if os.path.exists(os.path.join(src, "wordmark.png")):
        save_imageset("logo_wordmark", Image.open(os.path.join(src, "wordmark.png")).convert("RGBA"))
    if os.path.exists(os.path.join(src, "app_icon_1024.png")):
        write_app_icon(os.path.join(src, "app_icon_1024.png"))

    render_preview(s, frames).convert("RGB").save(os.path.join(ROOT, "art", "preview.png"))

    items = [v for k, v in s.items() if not k.startswith(("tile_grass_edge", "font_", "shadow_"))]
    sw = sum(im.width + 2 for im in items)
    sheet = Image.new("RGBA", (sw, 48), (40, 34, 50, 255))
    x = 0
    for im in items:
        sheet.alpha_composite(im, (x, 48 - im.height))
        x += im.width + 2
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(ROOT, "art", "sheet.png"))
    print("wrote %d sprites" % len(s))


if __name__ == "__main__":
    main()
