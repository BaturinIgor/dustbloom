"""Farm Defense battle sprites in the approved cozy daytime style: the
Dust Storm's land-1 creatures with walk cycles, the land boss, projectiles
and hit effects. Original designs. Drawn at 1 px = 1.5 pt (same as the farm).

sprites() returns {name: image}; names start with "def_"."""
import math

from PIL import Image

from . import palette as P
from .draw import ball, glow, line, new, outline, put, rect

EYE = "#ff5a3a"
EYE_HI = "#ffd27a"


def _shadow(im, cx, cy, rx, ry, a=90):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                put(im, x, y, "#2a2014", a)


def _eyes(im, pts, c=EYE):
    for (x, y) in pts:
        put(im, x, y, c)
        put(im, x, y - 1, EYE_HI)


# ---------------------------------------------------------------- dust beetle
def dust_beetle(f):
    """Basic walker: a round shell beetle crusted with dust. 4 walk frames."""
    im = new(22, 18)
    bob = (0, -1, 0, -1)[f]
    _shadow(im, 11, 15, 8, 2.4)
    # legs: three pairs, alternate pairs lift on odd frames
    for i, lx in enumerate((4, 7, 10)):
        up = (i + f) % 2
        line(im, lx, 11 + bob, lx - 3, 14 - up, "#3a2418")
        line(im, 22 - lx - 1, 11 + bob, 22 - lx + 2, 14 - (1 - up), "#3a2418")
    ball(im, 11, 9 + bob, 8, 5.6, "dust", lo=0.05, hi=0.8)
    # shell seam and dust crust
    line(im, 11, 4 + bob, 11, 14 + bob, P.RAMPS["dust"][1])
    for (x, y) in ((7, 7), (14, 8), (9, 11), (15, 11)):
        put(im, x, y + bob, P.RAMPS["dust"][5])
    ball(im, 11, 14 + bob, 4, 2.4, "soil", lo=0.1, hi=0.6)
    _eyes(im, ((9, 15 + bob), (13, 15 + bob)))
    # antennae
    put(im, 8, 17 + bob, "#3a2418")
    put(im, 14, 17 + bob, "#3a2418")
    return outline(im)


# ---------------------------------------------------------------- locust
def locust(f):
    """Flying, fast: a lean locust with buzzing wings. 2 frames."""
    im = new(22, 20)
    _shadow(im, 11, 18, 5, 1.6, 70)
    hover = (0, -1)[f]
    y = 8 + hover
    # wings (behind body), translucent
    wing = ("#e8f0d8", "#c8dcb0")
    spread = (7, 4)[f]
    for s in (-1, 1):
        for k in range(spread + 3):
            for t in range(-1, 2):
                put(im, 11 + s * (2 + k), y - 2 + t + (k // 3) * (1 if f else -1), wing[(k + t) % 2], 170)
    ball(im, 11, y + 3, 3.2, 6.2, "leaf", lo=0.2, hi=0.85)
    ball(im, 11, y - 3, 3.2, 3, "leaf", lo=0.35, hi=0.95)
    for k in range(3):
        put(im, 10, y + 2 + k * 2, P.RAMPS["leaf"][2])
    # legs folded
    line(im, 8, y + 4, 6, y + 8, "#3a2418")
    line(im, 14, y + 4, 16, y + 8, "#3a2418")
    _eyes(im, ((9, y - 2), (13, y - 2)), "#ff8a3a")
    return outline(im)


# ---------------------------------------------------------------- tumbleweed
def tumbleweed(f):
    """Very fast, rolls: a dry thorn ball. 4 rotation frames."""
    im = new(20, 20)
    _shadow(im, 10, 18, 7, 1.8)
    bounce = (0, -2, -1, 0)[f]
    cx, cy, r = 10, 10 + bounce, 7.5
    a0 = f * math.pi / 8
    for k in range(14):
        a = a0 + k * math.pi / 7
        for t in range(-7, 8):
            x = cx + math.cos(a) * t + math.sin(a * 3) * 1.5
            y = cy + math.sin(a) * t * 0.9
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                c = P.RAMPS["straw"][2 + (k + t) % 3] if "straw" in P.RAMPS else "#c8a060"
                put(im, int(x), int(y), c)
    for (dx, dy) in ((-3, -2), (2, 3), (4, -3)):
        put(im, cx + dx, cy + dy, "#3a2418")
    _eyes(im, ((cx - 2, cy), (cx + 2, cy)))
    return outline(im)


# ---------------------------------------------------------------- mole rat
def molerat(f):
    """Burrower, tanky: digs under and pops up near the fence. 4 frames."""
    im = new(24, 20)
    bob = (0, -1, 0, -1)[f]
    _shadow(im, 12, 17, 9, 2.4)
    # feet
    for i, fx in enumerate((6, 17)):
        up = (i + f) % 2
        rect(im, fx - 1, 15 - up, fx + 1, 16 - up, "#e0a090")
    ball(im, 12, 11 + bob, 9, 6, "soil", lo=0.15, hi=0.85)
    # snout, pink nose and teeth
    ball(im, 12, 14 + bob, 4.5, 3, "skin", lo=0.2, hi=0.9)
    put(im, 12, 13 + bob, "#e06a7a")
    put(im, 11, 16 + bob, "#fff4e0")
    put(im, 13, 16 + bob, "#fff4e0")
    # tiny eyes and dirt clods on the back
    _eyes(im, ((8, 10 + bob), (16, 10 + bob)))
    for (x, y) in ((7, 7), (15, 6), (11, 6)):
        put(im, x, y + bob, P.RAMPS["soil"][5])
    # claws
    for x in (5, 19):
        line(im, x, 12 + bob, x + (1 if x < 12 else -1), 15 + bob, "#f0e0c0")
    return outline(im)


# ---------------------------------------------------------------- boss
def locust_queen(f):
    """Land-1 boss: a huge armoured locust queen. 4 frames (wings + bob)."""
    im = new(56, 52)
    bob = (0, -1, -2, -1)[f]
    _shadow(im, 28, 48, 18, 4, 110)
    # wings
    spread = (12, 15, 12, 9)[f]
    for s in (-1, 1):
        for k in range(spread + 6):
            for t in range(-3, 4):
                if abs(t) > 3 - k // 8:
                    continue
                x = 28 + s * (6 + k)
                y = 18 + bob + t - k // 3
                put(im, x, y, ("#eef4dc", "#d0e0b4", "#b4cc98")[(k + t) % 3], 185)
    # abdomen, thorax, head
    ball(im, 28, 34 + bob, 9, 12, "leaf", lo=0.05, hi=0.7)
    for k in range(5):
        line(im, 21, 28 + k * 4 + bob, 35, 28 + k * 4 + bob, P.RAMPS["leaf"][1])
    ball(im, 28, 20 + bob, 9, 7, "leaf", lo=0.2, hi=0.9)
    ball(im, 28, 11 + bob, 7, 6, "leaf", lo=0.3, hi=1.0)
    # crown of dust-gold spikes
    for k, x in enumerate((22, 25, 28, 31, 34)):
        h = (3, 5, 7, 5, 3)[k]
        line(im, x, 6 + bob, x, 6 - h + bob, "#e8b040")
        put(im, x, 6 - h + bob, "#fff0a0")
    # big eyes and mandibles
    for ex in (24, 32):
        ball(im, ex, 11 + bob, 2.4, 2.2, "glow", lo=0.0, hi=0.6) if "glow" in P.RAMPS else None
        put(im, ex, 11 + bob, EYE)
        put(im, ex - 1, 10 + bob, EYE_HI)
    line(im, 25, 16 + bob, 23, 19 + bob, "#3a2418")
    line(im, 31, 16 + bob, 33, 19 + bob, "#3a2418")
    # legs
    for i, y in enumerate((22, 26, 30)):
        up = (i + f) % 2
        line(im, 20, y + bob, 12, y + 8 - up * 2, "#3a2418")
        line(im, 36, y + bob, 44, y + 8 - (1 - up) * 2, "#3a2418")
    glow(im, 28, 11 + bob, 10, "#ffce50", 0.15)
    return outline(im)


# ---------------------------------------------------------------- projectiles and fx
def ember():
    """Ember Pepper shot: a hot seed with a glow."""
    im = new(9, 9)
    glow(im, 4, 4, 4.5, "#ffae40", 0.7)
    ball(im, 4, 4, 2.2, 2.2, "pumpkin", lo=0.5, hi=1.0) if "pumpkin" in P.RAMPS else rect(im, 3, 3, 5, 5, "#ff8a30")
    put(im, 3, 3, "#fff4c0")
    return im


def arrow():
    """Crow Archer arrow, pointing right (rotated in game)."""
    im = new(12, 5)
    line(im, 1, 2, 9, 2, "#8a5a32")
    put(im, 10, 2, "#dcd6da")
    put(im, 11, 2, "#ffffff")
    put(im, 9, 1, "#dcd6da")
    put(im, 9, 3, "#dcd6da")
    for x in (1, 2):
        put(im, x, 1, "#f0f0f0")
        put(im, x, 3, "#d02a3a")
    return im


def frost():
    """Frost bolt (Frost Sentinel, Frost Cabbage)."""
    im = new(9, 9)
    glow(im, 4, 4, 4.5, "#a8e8ff", 0.7)
    for (x, y) in ((4, 1), (4, 7), (1, 4), (7, 4)):
        line(im, 4, 4, x, y, "#d8f6ff")
    put(im, 4, 4, "#ffffff")
    return im


def hit(f):
    """Impact spark, 3 frames, additive in game."""
    im = new(13, 13)
    r = (2.5, 4.5, 6)[f]
    a = (255, 200, 110)[f]
    for k in range(8):
        ang = k * math.pi / 4 + (0.4 if f == 1 else 0)
        for t in range(int(r * 0.4), int(r) + 1):
            put(im, int(6.5 + math.cos(ang) * t), int(6.5 + math.sin(ang) * t),
                "#fff2b0" if t < r * 0.7 else "#ffae40", a)
    if f == 0:
        glow(im, 6, 6, 4, "#ffffff", 0.9)
    return im


def poof(f):
    """Death puff of dust, 4 frames."""
    im = new(20, 20)
    r = (3, 5.5, 7.5, 9)[f]
    a = (230, 190, 130, 60)[f]
    for k, (dx, dy) in enumerate(((0, 0), (-4, 2), (4, 1), (-2, -3), (3, -3))):
        rr = r * (1 - k * 0.12)
        for y in range(int(10 + dy - rr), int(10 + dy + rr) + 1):
            for x in range(int(10 + dx - rr), int(10 + dx + rr) + 1):
                if (x - 10 - dx) ** 2 + (y - 10 - dy) ** 2 <= rr * rr:
                    c = P.RAMPS["dust"][5] if y < 10 + dy else P.RAMPS["dust"][3]
                    put(im, x, y, c, a)
    return im


def dust_cloud():
    """Soft storm cloud puff (smooth filtered, tinted per land)."""
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 15.5, y - 15.5) / 16
            if d < 1:
                im.putpixel((x, y), (255, 255, 255, int(255 * (1 - d) ** 1.6)))
    return im


def shadow():
    im = new(16, 6)
    _shadow(im, 8, 3, 7.5, 2.6, 110)
    return im


def sprites():
    out = {}
    for f in range(4):
        out["def_beetle_%d" % f] = dust_beetle(f)
        out["def_tumble_%d" % f] = tumbleweed(f)
        out["def_molerat_%d" % f] = molerat(f)
        out["def_queen_%d" % f] = locust_queen(f)
        out["def_poof_%d" % f] = poof(f)
    for f in range(2):
        out["def_locust_%d" % f] = locust(f)
    for f in range(3):
        out["def_hit_%d" % f] = hit(f)
    out["def_ember"] = ember()
    out["def_arrow"] = arrow()
    out["def_frost"] = frost()
    out["def_cloud"] = dust_cloud()
    out["def_shadow"] = shadow()
    return out
