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
    s["ui_coin"] = coin()
    s["ui_cursor"] = cursor()
    s["fx_sparkle"] = sparkle()
    return s


# ---- ground rule shared with the client (FarmScene.groundTexture)
def is_green(tilled, x, y, w, h):
    """Grass grows around tilled beds: the farm brings life to the wasteland.
    A tile is green when the nearest bed is within 2.3 tiles (rounded corners)."""
    best = 99.0
    for yy in range(max(0, y - 3), min(h, y + 4)):
        for xx in range(max(0, x - 3), min(w, x + 4)):
            if tilled[yy][xx]:
                best = min(best, math.hypot(xx - x, yy - y))
    return best <= 2.3


def ground_name(tilled, x, y, w, h):
    if tilled[y][x]:
        return "tile_bed"
    if not is_green(tilled, x, y, w, h):
        return "tile_dust_%d" % ((x * 7 + y * 13) % 3)

    def g(xx, yy):
        if not (0 <= xx < w and 0 <= yy < h):
            return True
        return is_green(tilled, xx, yy, w, h)
    mask = (1 if g(x, y - 1) else 0) | (2 if g(x + 1, y) else 0) | (4 if g(x, y + 1) else 0) | (8 if g(x - 1, y) else 0)
    if mask == 15:
        v = (x * 5 + y * 3) % 7
        return "tile_grass_%d" % (1 if v == 0 else 2 if v == 3 else 0)
    return "tile_grass_edge_%d" % mask


def find_font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def render_preview(s):
    """Phone-screen mockup, 390x844 pt rendered at @2x, tiles 48 pt (16 px x3)."""
    W, H, PX = 390, 844, 3
    cols, rows = 12, 22
    tilled = [[False] * cols for _ in range(rows)]
    for y in range(9, 13):
        for x in range(4, 8):
            tilled[y][x] = True
    world = Image.new("RGBA", (cols * T, rows * T))
    for y in range(rows):
        for x in range(cols):
            world.alpha_composite(s[ground_name(tilled, x, y, cols, rows)], (x * T, y * T))
    # props
    for x in range(3, 9):
        world.alpha_composite(s["prop_fence"], (x * T, 7 * T - 6))
    world.alpha_composite(s["prop_scarecrow"], (2 * T + 4, 10 * T - 4))
    world.alpha_composite(s["prop_rock"], (9 * T + 6, 4 * T))
    world.alpha_composite(s["prop_rock"], (1 * T, 16 * T + 4))
    world.alpha_composite(s["prop_dead_tree"], (8 * T, 15 * T))
    world.alpha_composite(s["prop_dead_tree"], (0 * T, 2 * T))
    crops = {
        (4, 9): "dustwheat_3", (5, 9): "dustwheat_3", (6, 9): "dustwheat_2", (7, 9): "dustwheat_1",
        (4, 10): "emberpumpkin_3", (5, 10): "emberpumpkin_3", (6, 10): "emberpumpkin_2", (7, 10): "emberpumpkin_1",
        (4, 11): "moonturnip_3", (5, 11): "moonturnip_2", (6, 11): "moonturnip_1", (7, 11): "dustwheat_0",
        (4, 12): "dustwheat_3", (5, 12): "emberpumpkin_0",
    }
    for (x, y), name in sorted(crops.items(), key=lambda kv: kv[0][1]):
        world.alpha_composite(s[name], (x * T, (y + 1) * T - CH))
    world.alpha_composite(s["ui_cursor"], (5 * T, 10 * T))
    world.alpha_composite(s["fx_sparkle"], (5 * T + 11, 10 * T - 9))
    world.alpha_composite(s["fx_sparkle"], (4 * T + 2, 9 * T - 13))

    # camera: crop a phone-sized window centred on the farm
    view_w, view_h = W // PX, H // PX  # in pixels
    cx, cy = 6 * T, 11 * T
    view = world.crop((cx - view_w // 2, cy - view_h // 2, cx - view_w // 2 + view_w, cy - view_h // 2 + view_h))
    screen = view.resize((view_w * PX * 2, view_h * PX * 2), Image.NEAREST)

    # warm evening light + vignette (also used in-game as an overlay)
    sw, sh = screen.size
    light = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.ellipse((-sw * 0.3, -sh * 0.05, sw * 1.3, sh * 1.0), fill=(255, 200, 120, 36))
    light = light.filter(ImageFilter.GaussianBlur(120))
    screen.alpha_composite(light)
    vig = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(vig).ellipse((-sw * 0.25, -sh * 0.12, sw * 1.25, sh * 1.12), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGBA", (sw, sh), (20, 12, 26, 150))
    dark.putalpha(Image.eval(vig, lambda v: int((255 - v) * 0.6)))
    screen.alpha_composite(dark)

    # HUD (mirrors HUDView.swift), drawn at @2x
    hud = ImageDraw.Draw(screen)
    k = 2
    parch, shade, outl, ink = rgba("white")[:3], (226, 204, 154), (43, 29, 22), (58, 42, 32)
    gold, gold_d = (255, 224, 138), (232, 180, 67)
    f = find_font(17 * k)
    fs = find_font(13 * k)

    def pill(x, y, w, text, icon=None):
        hud.rounded_rectangle((x, y, x + w, y + 34 * k), radius=17 * k, fill=(244, 230, 196), outline=outl, width=3 * k)
        tx = x + 12 * k
        if icon is not None:
            screen.alpha_composite(icon.resize((22 * k, 22 * k), Image.NEAREST), (tx, y + 6 * k))
            tx += 28 * k
        hud.text((tx, y + 7 * k), text, font=f, fill=ink)

    top = 58 * k
    pill(16 * k, top, 110 * k, "126", s["ui_coin"])
    pill(134 * k, top, 72 * k, "LV 3")
    # crop bar
    bw, bh = 3 * 74 * k + 2 * 12 * k + 20 * k, 96 * k
    bx, by = (sw - bw) // 2, sh - bh - 34 * k
    hud.rounded_rectangle((bx, by, bx + bw, by + bh), radius=14 * k, fill=(244, 230, 196), outline=outl, width=3 * k)
    for i, (cid, cost) in enumerate((("dustwheat", 2), ("emberpumpkin", 8), ("moonturnip", 20))):
        x = bx + 10 * k + i * (74 * k + 12 * k)
        y = by + 10 * k
        sel = i == 1
        hud.rounded_rectangle((x, y, x + 74 * k, y + 76 * k), radius=10 * k,
                              fill=gold if sel else shade, outline=gold_d if sel else None, width=3 * k)
        spr = s[cid + "_3"].crop((0, 4, CW, CH))  # trim empty top
        spr = spr.resize((spr.width * 3 * k // 1, spr.height * 3 * k // 1), Image.NEAREST)
        spr = spr.resize((spr.width * 2 // 3, spr.height * 2 // 3), Image.NEAREST)
        screen.alpha_composite(spr, (x + (74 * k - spr.width) // 2, y + 2 * k))
        screen.alpha_composite(s["ui_coin"].resize((14 * k, 14 * k), Image.NEAREST), (x + 22 * k, y + 56 * k))
        hud.text((x + 40 * k, y + 54 * k), str(cost), font=fs, fill=ink)

    # floating "+22" over the harvested pumpkin
    fb = find_font(22 * k)
    hx, hy = (5 * T - (cx - view_w // 2)) * PX * k + 6 * k, (10 * T - 14 - (cy - view_h // 2)) * PX * k
    for ox, oy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
        hud.text((hx + ox, hy + oy), "+22", font=fb, fill=outl)
    hud.text((hx, hy), "+22", font=fb, fill=gold)
    return screen


def main():
    os.makedirs(ASSETS, exist_ok=True)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    s = build_sprites()
    # drop images from older generator versions
    for d in os.listdir(ASSETS):
        if d.endswith(".imageset") and d[:-9] not in s and d != "logo_wordmark.imageset":
            for f in os.listdir(os.path.join(ASSETS, d)):
                os.remove(os.path.join(ASSETS, d, f))
            os.rmdir(os.path.join(ASSETS, d))
    for name, im in s.items():
        save_imageset(name, im)

    src = os.path.join(ROOT, "art", "source")
    if os.path.exists(os.path.join(src, "wordmark.png")):
        save_imageset("logo_wordmark", Image.open(os.path.join(src, "wordmark.png")).convert("RGBA"))
    if os.path.exists(os.path.join(src, "app_icon_1024.png")):
        write_app_icon(os.path.join(src, "app_icon_1024.png"))

    render_preview(s).convert("RGB").save(os.path.join(ROOT, "art", "preview.png"))

    items = [v for k, v in s.items() if not k.startswith("tile_grass_edge")]
    sw = sum(im.width + 2 for im in items)
    sheet = Image.new("RGBA", (sw, 32), (40, 34, 50, 255))
    x = 0
    for im in items:
        sheet.alpha_composite(im, (x, 32 - im.height))
        x += im.width + 2
    sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(os.path.join(ROOT, "art", "sheet.png"))
    print("wrote %d sprites" % len(s))


if __name__ == "__main__":
    main()
