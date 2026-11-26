"""Splash scene layers in the icon's style (130 x 282 art px = 390 x 846 pt
at 3 pt per pixel). The game animates them: the sun and rays rise, mesas
and hills slide in with parallax, the scarecrow rises from the wheat and
its eyes light up, then the logo drops in."""
import math
import random

from PIL import Image

from . import objects as O
from .draw import ball, glow, mix, new, outline, put, rect, sparkle
from .palette import RAMPS, dither, fbm, hash01, noise2, ramp_d

R = RAMPS
W, H = 130, 282
HORIZON = 176


def sky():
    im = new(W, H)
    for y in range(H):
        for x in range(W):
            # bands: deep purple top -> magenta -> orange -> cream at the horizon
            t = min(1.0, max(0.0, y / HORIZON))
            t = t ** 1.35
            put(im, x, y, ramp_d("sky", t * 0.98, x, y, 1.0))
    rnd = random.Random(7)
    for _ in range(46):  # stars in the dark top
        x, y = rnd.randrange(W), rnd.randrange(int(HORIZON * 0.42))
        put(im, x, y, "#fff4f0" if rnd.random() < 0.6 else "#c2b0e0")
    for (x, y) in ((22, 30), (104, 18), (88, 62)):
        sparkle(im, x, y, 2)
    # thin clouds lit from below
    for (cx, cy, w) in ((30, 118, 34), (100, 104, 28), (64, 138, 40)):
        for x in range(cx - w // 2, cx + w // 2):
            k = 1 - abs(x - cx) / (w / 2)
            hgt = int(1 + k * 2.5)
            for y in range(cy - hgt, cy + 1):
                put(im, x, y, R["sky"][3] if y < cy else R["sky"][5])
    return im


def sun():
    im = new(64, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x + 0.5 - 32, y + 0.5 - 32)
            if d <= 20:
                t = 1 - (y / 64) * 0.5
                put(im, x, y, ramp_d("glow", 0.4 + t * 0.38, x, y))
            elif d <= 31:
                a = (31 - d) / 11
                if dither(x, y, a * 0.9):
                    put(im, x, y, "#ffce50" if d < 25 else "#ff9628", int(255 * min(1, a + 0.3)))
    return im


def rays():
    """Smooth rays texture (linear filtering, additive in game)."""
    n = 128
    im = Image.new("RGBA", (n, n))
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - n / 2, y + 0.5 - n / 2
            d = math.hypot(dx, dy) / (n / 2)
            if d > 1:
                continue
            a = math.atan2(dy, dx)
            s = max(0.0, math.cos(a * 9)) ** 3
            alpha = s * (1 - d) ** 1.5 * 150
            im.putpixel((x, y), (255, 190, 110, int(alpha)))
    return im


def ridge(width, height, seed, base, amp, ramp_name, lo, hi, trees=0):
    im = new(width, height)
    tops = []
    for x in range(width):
        top = base - (fbm(x, 0, seed, 30, 3) * amp + noise2(x, 0, seed + 3, 6) * amp * 0.25)
        top = int(max(0, top))
        tops.append(top)
        for y in range(top, height):
            depth = (y - top) / max(1, height - top)
            lit = 1 - x / width  # sun on the left
            t = lo + (hi - lo) * (0.55 * (1 - depth) + 0.25 * lit) + fbm(x, y, seed + 9, 8, 2) * 0.06
            put(im, x, y, ramp_d(ramp_name, t, x, y))
        put(im, x, top, R["sky"][6] if x < width * 0.55 else R["sky"][4])  # sunset rim light
    rnd = random.Random(seed)
    for _ in range(trees):
        x = rnd.randrange(6, width - 6)
        t = O.dead_tree(rnd.randrange(9))
        small = t.resize((t.width // 2, t.height // 2), Image.NEAREST)
        im.alpha_composite(small, (x - small.width // 2, tops[x] - small.height + 2))
    return im


def wheat_field():
    im = new(150, 64)
    rnd = random.Random(3)
    for y in range(64):
        for x in range(150):
            t = 0.25 + (y / 64) * 0.1 + fbm(x, y, 2, 10, 2) * 0.05
            put(im, x, y, ramp_d("straw", t, x, y))
    for _ in range(420):
        x = rnd.randrange(150)
        y0 = rnd.randrange(4, 64)
        h = rnd.randint(6, 12)
        lit = x < 75
        for k in range(h):
            put(im, x, y0 - k, R["straw"][3 if lit else 2])
        for k in range(4):
            put(im, x, y0 - h - k, R["straw"][5 if lit else 4] if k < 2 else R["straw"][4])
    return im


def stalk(seed):
    """One tall foreground stalk (sways in the game)."""
    rnd = random.Random(seed)
    im = new(10, 50)
    for y in range(14, 50):
        put(im, 5, y, R["straw"][1])
    for k in range(13):
        put(im, 4, 14 - k, ramp_d("straw", 0.95 - k * 0.04, 4, k))
        put(im, 5, 14 - k + 1, ramp_d("straw", 0.65 - k * 0.03, 5, k))
        if k % 2 == 0:
            put(im, 6, 15 - k, R["straw"][2])
            put(im, 3, 15 - k, R["straw"][3])
    put(im, 4, 0, R["straw"][5])
    for k in range(3):  # leaves
        y = 26 + k * 7 + rnd.randint(-2, 2)
        d = 1 if k % 2 else -1
        for j in range(5):
            put(im, 5 + d * j, y + j // 2, R["leaf"][1])
    outline(im, "#1e101e")
    return im


def hero():
    """The scarecrow, with the eyes and mouth on their own layer."""
    sc = O.scarecrow()
    eyes = new(sc.width, sc.height)
    for y in range(sc.height):
        for x in range(sc.width):
            r, g, b, a = sc.getpixel((x, y))
            if a and r > 240 and g > 190 and 14 < y < 36:
                eyes.putpixel((x, y), (r, g, b, 255))
    return sc, eyes


def crow(frame):
    im = new(13, 8)
    body = R["ui"]
    ball(im, 6, 4, 3, 1.8, "cape", lo=0.0, hi=0.3)
    if frame == 0:
        for k in range(5):
            put(im, 6 - k, 3 - k // 2, body[2])
            put(im, 6 + k, 3 - k // 2, body[2])
    else:
        for k in range(5):
            put(im, 6 - k, 4 + k // 3, body[2])
            put(im, 6 + k, 4 + k // 3, body[2])
    put(im, 10, 4, "#f0a02e")
    return im


def layers():
    sc, eyes = hero()
    return {
        "intro_sky": sky(),
        "intro_sun": sun(),
        "intro_mesa": ridge(150, 60, 11, 26, 22, "stone", 0.1, 0.5),
        "intro_hills": ridge(150, 74, 4, 30, 14, "dust", 0.05, 0.55, trees=3),
        "intro_field": wheat_field(),
        "intro_stalk_0": stalk(1), "intro_stalk_1": stalk(2), "intro_stalk_2": stalk(3),
        "intro_hero": sc, "intro_hero_eyes": eyes,
        "intro_crow_0": crow(0), "intro_crow_1": crow(1),
    }, {"intro_rays": rays()}


def preview(path):
    """The finished splash (as it rests after the animation)."""
    L, smooth = layers()
    im = new(W, H)
    im.alpha_composite(L["intro_sky"])
    r = smooth["intro_rays"].resize((140, 140), Image.BILINEAR)
    im.alpha_composite(r, (W // 2 - 70, HORIZON - 40 - 70))
    im.alpha_composite(L["intro_sun"], (W // 2 - 32, HORIZON - 40 - 32))
    im.alpha_composite(L["intro_mesa"], (-10, HORIZON - 34))
    im.alpha_composite(L["intro_hills"], (-10, HORIZON - 12))
    im.alpha_composite(L["intro_field"], (-10, H - 64))
    sc = L["intro_hero"]
    im.alpha_composite(sc, (W // 2 - sc.width // 2, H - 64 - sc.height + 46))
    glow(im, W // 2, H - 64 - sc.height + 46 + 30, 16, "#ffce50", 0.4)
    for i, x in enumerate((6, 18, 104, 118, 40, 92)):
        s = L["intro_stalk_%d" % (i % 3)]
        im.alpha_composite(s, (x, H - s.height + 4))
    im.alpha_composite(L["intro_crow_0"], (24, 70))
    im.alpha_composite(L["intro_crow_1"], (94, 52))
    big = im.resize((W * 6, H * 6), Image.NEAREST)
    logo = Image.open("source/wordmark.png").convert("RGBA")
    k = (W * 6 * 0.86) / logo.width
    logo = logo.resize((int(logo.width * k), int(logo.height * k)), Image.NEAREST)
    big.alpha_composite(logo, ((big.width - logo.width) // 2, 60 * 6))
    big.convert("RGB").save(path)
