"""Game sprites in the approved cozy daytime style (target-frame-day.png),
drawn at 32 px per tile. They keep the names and the on-screen size of the
old 16 px sprites and ship as @2x images, so the game code is unchanged:
SpriteKit sizes them in points from the 1x size, and shows every pixel.

hd_sprites(old) returns {name: image at 2x}. Anything not redrawn yet is
the old sprite scaled 2x with nearest neighbour, so sizes always match."""
import math
import random

from PIL import Image

from . import palette as P
from .frame_day import DAY

T = 32  # pixels per tile
WORLD_PREFIXES = ("tile_", "prop_", "shadow_", "bld_", "edge_")


def setup():
    """Switch the shared drawing helpers to the daytime look."""
    P.RAMPS.update(DAY)
    P.INK = "#3a2418"
    from . import draw
    draw.INK = "#3a2418"
    draw.outline.__defaults__ = ("#3a2418", True, 0.75)
    draw.cast_shadow.__defaults__ = (None, 0.55, 0.3, "#1c3418", 120)


def _wrap(f, x, y, n=T):
    """Make a noise function seamless on an n x n tile (torus blend)."""
    x, y = x % n, y % n
    a, b = x / n, y / n
    return (f(x, y) * (1 - a) * (1 - b) + f(x - n, y) * a * (1 - b)
            + f(x, y - n) * (1 - a) * b + f(x - n, y - n) * a * b)


# ---------------------------------------------------------------- ground
def tile_grass(seed, flowers=0):
    from .draw import new, put
    R = P.RAMPS
    g = R["grass"]
    im = new(T, T)
    for y in range(T):
        for x in range(T):
            n = _wrap(lambda u, v: P.fbm(u, v, seed, 14, 3), x, y)
            put(im, x, y, P.ramp_d("grass", 0.42 + n * 0.24, x, y, 0.9))
    rnd = random.Random(seed)
    for _ in range(26):  # tufts, wrapped so they tile
        x, y = rnd.randrange(T), rnd.randrange(T)
        hi = rnd.random() < 0.55
        for dx, dy, c in ((0, 1, g[2] if hi else g[1]), (0, 0, g[4] if hi else g[3]),
                          (-1, -1, g[4] if hi else g[3]), (1, -1, g[5] if hi else g[3])):
            put(im, (x + dx) % T, (y + dy) % T, c)
    for _ in range(flowers * 2):
        x, y = rnd.randrange(3, T - 3), rnd.randrange(3, T - 3)
        petal = rnd.choice(("#ffd6dc", "#fff4a0", "#ffffff", "#c8b4f0"))
        put(im, x, y + 1, g[1])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(im, x + dx, y + dy, petal)
        put(im, x, y, "#ffce50")
    return im


def tile_dust(seed):
    from .draw import ball, new, put
    R = P.RAMPS
    im = new(T, T)
    for y in range(T):
        for x in range(T):
            n = _wrap(lambda u, v: P.fbm(u, v, seed, 16, 3), x, y)
            c = P.ramp_d("dust", 0.5 + n * 0.14, x, y, 0.6)
            put(im, x, y, c)
    rnd = random.Random(seed)
    for _ in range(1 + seed % 2):
        x, y = rnd.randrange(5, T - 5), rnd.randrange(5, T - 5)
        r = rnd.choice((1.0, 1.4, 1.8))
        put(im, x + 1, y + r + 0.5, R["dust"][1])
        ball(im, x, y, r + 0.4, r, "dust", lo=0.35, hi=1.0)
    return im


def _depth(i, seed):
    return 2 + int((math.sin(i * 0.85 + seed) + math.sin(i * 0.3 + seed * 2)) * 1.2 + 2.4) % 5


def tile_grass_edge(mask, dust, grass):
    """Raised turf: sides that face dust (bit clear) are carved into a ragged
    edge with a soil lip below and a lit rim above. 1=N 2=E 4=S 8=W green."""
    from .draw import put
    R = P.RAMPS
    g, s, d = R["grass"], R["soil"], R["dust"]
    im = dust.copy()
    carve = [[False] * T for _ in range(T)]
    for i in range(T):
        for bit, seed, fn in ((1, 1, lambda i, j: (i, j)), (4, 3, lambda i, j: (i, T - 1 - j)),
                              (8, 5, lambda i, j: (j, i)), (2, 7, lambda i, j: (T - 1 - j, i))):
            if not mask & bit:
                for j in range(_depth(i, seed)):
                    x, y = fn(i, j)
                    carve[y][x] = True
    for y in range(T):
        for x in range(T):
            if not carve[y][x]:
                im.putpixel((x, y), grass.getpixel((x, y)))
    for y in range(T):
        for x in range(T):
            if carve[y][x]:
                if y > 0 and not carve[y - 1][x]:
                    put(im, x, y, d[1])  # turf casts a shadow on the dust
                continue
            below = [y + k < T and carve[y + k][x] for k in (1, 2, 3)]
            if below[0]:
                put(im, x, y, s[2] if P.dither(x, y, 0.5) else s[3])
            elif below[1]:
                put(im, x, y, s[3])
            elif below[2]:
                put(im, x, y, g[1])
            elif y > 0 and carve[y - 1][x]:
                put(im, x, y, g[6] if P.dither(x, y, 0.6) else g[5])
            elif (x > 0 and carve[y][x - 1]) or (x + 1 < T and carve[y][x + 1]):
                put(im, x, y, g[2])
    return im


def tile_bed(seed=7):
    """One raised, furrowed mound on trodden soil; neighbouring beds join
    into a field like in the target frame."""
    from .draw import new, put
    im = new(T, T)
    s = P.RAMPS["soil"]
    for y in range(T):
        for x in range(T):
            n = _wrap(lambda u, v: P.fbm(u, v, seed, 6, 2), x, y)
            put(im, x, y, P.ramp_d("soil", 0.3 + n * 0.12, x, y))
    l, t, r, b = 2, 2, T - 3, T - 3
    for y in range(t, b + 1):
        for x in range(l, r + 1):
            if (x in (l, r) and y in (t, t + 1, b, b - 1)) or (x in (l + 1, r - 1) and y in (t, b)):
                continue
            if y >= b - 3:
                tt = 0.2 if y == b else 0.3
            elif y <= t + 1:
                tt = 0.82
            else:
                tt = 0.6 - (x - l) / (r - l) * 0.12
                fy = int(y - t - 2 + P.noise2(x, y, seed, 3) * 1.6) % 8
                if fy == 0:
                    tt = 0.74 if P.dither(x, y, 0.6) else 0.62
                elif fy == 1:
                    tt = 0.7
                elif fy in (6, 7):
                    tt = 0.38
                if P.hash01(x, y, seed) < 0.08:
                    tt += 0.18
                elif P.hash01(x, y, seed + 1) < 0.08:
                    tt -= 0.15
            if x in (l, r):
                tt -= 0.12
            put(im, x, y, P.ramp_d("soil", tt, x, y))
    for x in range(l + 1, r + 2):
        put(im, x, b + 1, s[0] if P.dither(x, b, 0.5) else s[1])
    return im


# ---------------------------------------------------------------- crops
def _crop_canvas(im):
    """hd crops are 32x44 with the base near the bottom; the game canvas is
    32x48 (16x24 at 2x) with the base on row 40."""
    from .draw import new
    out = new(32, 48)
    bottom = im.getbbox()[3] if im.getbbox() else 42
    out.alpha_composite(im, (0, 42 - bottom))
    return out


def seed_mound(seed_col):
    from .draw import ball, new, outline, put
    im = new(32, 44)
    ball(im, 16, 38, 7, 3.2, "soil", lo=0.3, hi=0.95)
    ball(im, 16, 34.5, 1.8, 1.6, "pumpkin" if seed_col == "pumpkin" else "straw", lo=0.4, hi=1.0)
    put(im, 15, 33, "#ffffff")
    outline(im)
    return im


def crops():
    from . import objects as O
    s = {}
    s["dustwheat_0"] = seed_mound("straw")
    s["dustwheat_1"] = O.sprout(4)
    s["dustwheat_2"] = O.wheat(2)
    s["dustwheat_3"] = O.wheat(3)
    s["emberpumpkin_0"] = seed_mound("pumpkin")
    s["emberpumpkin_1"] = O.sprout(5)
    s["emberpumpkin_2"] = O.ember_pumpkin(2)
    s["emberpumpkin_3"] = O.ember_pumpkin(3)
    s["moonturnip_0"] = seed_mound("straw")
    s["moonturnip_1"] = O.sprout(6)
    s["moonturnip_2"] = O.moon_turnip(2)
    s["moonturnip_3"] = O.moon_turnip(3)
    from .crops_hd import sprites as more_crops
    s.update(more_crops(seed_mound))
    return {k: _crop_canvas(v) for k, v in s.items()}


# ---------------------------------------------------------------- props
def _fit(im, w, h, anchor="bottom"):
    """Place an hd drawing on a canvas of the old sprite's 2x size, centred
    horizontally and standing on the bottom edge."""
    from .draw import new
    if im.width > w or im.height > h:
        k = min(w / im.width, h / im.height)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
    out = new(w, h)
    out.alpha_composite(im, ((w - im.width) // 2, h - im.height if anchor == "bottom" else 0))
    return out


def props(old):
    from . import objects as O
    from .draw import cast_shadow
    s = {}
    for name, im in (("prop_rock", O.rock()), ("prop_dead_tree", O.dead_tree()), ("prop_scarecrow", O.scarecrow())):
        o = old[name]
        # hd art can be taller than the old canvas; keep its width, grow upward
        w, h = max(o.width * 2, im.width), max(o.height * 2, im.height)
        s[name] = _fit(im, w, h)
    for name in ("prop_rock", "prop_dead_tree", "prop_scarecrow"):
        s["shadow_" + name[5:]] = cast_shadow(s[name])
    return s


def hd_sprites(old):
    """Isometric game sprites (see hd/iso.py), calmer daytime palette."""
    setup()
    from .frame_iso import SOFT
    from . import iso as I
    P.RAMPS.update(SOFT)
    s = {}
    dust = [I.tile_dust(k) for k in (1, 2, 3)]
    grass = [I.tile_grass(11), I.tile_grass(12, 1), I.tile_grass(13, 2)]
    for i in range(3):
        s["tile_dust_%d" % i] = dust[i]
        s["tile_grass_%d" % i] = grass[i]
    for m in range(15):
        s["tile_grass_edge_%d" % m] = I.tile_grass_edge(m, grass[0], dust[0])
    s["tile_bed"] = I.tile_bed()
    s["ui_cursor"] = I.cursor()
    s["edge_fence_x"] = I.fence_edge(True)
    s["edge_fence_y"] = I.fence_edge(False)
    for k, v in crops().items():
        s[k] = I.crop_fit(v)
    s.update(props(old))
    from . import iso_objects
    s.update(iso_objects.sprites())
    out = {}
    for name, im in old.items():
        if name in s:
            out[name] = s[name]
        elif is_world(name):
            im2 = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            if name.split("_")[-1].isdigit() and im.size == (16, 24):  # old crop: trim to its base
                im2 = I.crop_fit(im2)
            out[name] = im2
    for name in ("edge_fence_x", "edge_fence_y"):
        out[name] = s[name]
    return out


def is_world(name):
    return name.startswith(WORLD_PREFIXES) or name.split("_")[-1].isdigit() and not name.startswith(
        ("font_", "item_", "icon_", "ui_", "intro_"))
