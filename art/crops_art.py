"""Nine more crops for stage 1. Each crop: seed, sprout, young, ripe.
Same 16x24 canvas and helpers as generate_sprites.py."""
from generate_sprites import (BASE, CH, CW, P, ball, dark_outline, get, leaf, line, new, put, rect,
                              seed_stage, shadow, sprout)

# extra ramps for the new crops
P.update({
    "b0": "#4a1030", "b1": "#7a1a3e", "b2": "#b3264a", "b3": "#e04a5c", "b4": "#ff8a8a",
    "f0": "#2c4f78", "f1": "#4f7fb0", "f2": "#86b4dc", "f3": "#c3e2f5", "f4": "#f2fbff",
    "v0": "#3a1d55", "v1": "#5e2f86", "v2": "#8a4cb6", "v3": "#b98ae0",
    "n0": "#3d4a2a", "n1": "#5c6e38", "n2": "#86984a",
})

GREEN = ("g1", "g2", "g3", "g4")


def _stem(im, x, y0, h, cols=("g2", "g3")):
    for j in range(h):
        put(im, x, y0 - j, cols[j % 2])


def carrot(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 5, 1.3)
    tall = 2 if stage == 3 else 0
    for i, dx in enumerate((-3, -1, 1, 3)):  # feathery fronds
        for j in range(6 + tall + (i % 2) * 2):
            put(im, 8 + dx + (j // 3) * (1 if dx > 0 else -1), BASE - 3 - j, "g3" if j % 2 else "g4")
    # carrot shoulders peeking out of the soil
    if stage == 3:
        for x, y, c in ((6, BASE - 1, "o3"), (7, BASE - 2, "o4"), (8, BASE - 2, "o3"), (9, BASE - 1, "o2"),
                        (7, BASE - 1, "o3"), (8, BASE - 1, "o2"), (7, BASE, "o2"), (8, BASE, "o1")):
            put(im, x, y, c)
    else:
        put(im, 7, BASE - 1, "o2")
        put(im, 8, BASE - 1, "o1")
    return dark_outline(im)


def sunflower(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 4, 1.2)
    h = 12 if stage == 2 else 15
    _stem(im, 8, BASE, h)
    leaf(im, 7, BASE - 5, -1)
    leaf(im, 9, BASE - 8, 1)
    top = BASE - h
    if stage == 2:
        ball(im, 8, top, 2, 2, ("g1", "g2", "g3", "g4", "g4", "g5"))
        return dark_outline(im)
    for k in range(12):  # petals
        import math
        a = k / 12 * 6.283
        put(im, 8 + round(math.cos(a) * 4.2), top + round(math.sin(a) * 3.6), "y3" if k % 2 else "y4")
        put(im, 8 + round(math.cos(a) * 3.2), top + round(math.sin(a) * 2.8), "y2")
    ball(im, 8, top, 2.4, 2.2, ("s0", "s1", "s2", "s3", "s3", "s4"))
    return dark_outline(im)


def berry_bush(stage, berry=("b1", "b2", "b3", "b4")):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 6.5, 1.5)
    r = 4.5 if stage == 2 else 6
    ball(im, 8, BASE - r, r + 0.6, r, ("g0", "g1", "g2", "g3", "g4", "g4"))
    if stage == 3:
        for (x, y) in ((4, BASE - 6), (9, BASE - 9), (11, BASE - 4), (6, BASE - 3), (12, BASE - 8), (7, BASE - 10)):
            put(im, x, y, berry[1])
            put(im, x + 1, y, berry[2])
            put(im, x, y - 1, berry[3])
            put(im, x + 1, y + 1, berry[0])
    return dark_outline(im)


def beans(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 4, 1.2)
    line(im, 8, BASE, 8, BASE - 18, "w2")  # pole
    put(im, 8, BASE - 18, "w3")
    h = 11 if stage == 2 else 17
    for j in range(h):  # vine winding around
        x = 8 + (1 if (j // 2) % 2 else -1)
        put(im, x, BASE - j, "g2" if j % 3 else "g3")
        if j % 4 == 1:
            put(im, x + (1 if x > 8 else -1), BASE - j, "g4")
    if stage == 3:
        for (x, y) in ((6, BASE - 6), (10, BASE - 9), (6, BASE - 12), (10, BASE - 14)):
            line(im, x, y, x, y + 3, "n2")
            put(im, x, y + 1, "n1")
    return dark_outline(im)


def cabbage(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 6.5, 1.5)
    if stage == 2:
        leaf(im, 3, BASE - 2, 1, ("f0", "f1", "f2", "f3"))
        leaf(im, 13, BASE - 2, -1, ("f0", "f1", "f2", "f3"))
        ball(im, 8, BASE - 3, 3, 2.6, ("f0", "f1", "f2", "f3", "f3", "f4"))
        return dark_outline(im)
    leaf(im, 1, BASE - 2, 1, ("f0", "f1", "f2", "f3"))
    leaf(im, 15, BASE - 2, -1, ("f0", "f1", "f2", "f3"))
    ball(im, 8, BASE - 5, 5.6, 5, ("f0", "f1", "f2", "f3", "f4", "f4"))
    for y in range(BASE - 9, BASE - 1):  # leaf veins
        put(im, 8 + (y % 3) - 1, y, "f1")
    for x, y in ((4, BASE - 9), (12, BASE - 8), (8, BASE - 11)):
        put(im, x, y, "f4")  # frost sparkle
    return dark_outline(im)


def pepper(stage):
    im = berry_bush(2)
    if stage == 3:
        for (x, y) in ((5, BASE - 5), (9, BASE - 7), (11, BASE - 3)):
            rect(im, x, y, x + 1, y + 3, "b3")
            put(im, x, y + 3, "b2")
            put(im, x + 1, y + 4, "b1")
            put(im, x, y - 1, "g2")
            put(im, x, y, "b4")
    return im


def cotton(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 5, 1.3)
    for sx, h in ((4, 9), (8, 12), (12, 10)):
        _stem(im, sx, BASE, h if stage == 3 else h - 3, ("n1", "n2"))
        put(im, sx + 1, BASE - h // 2, "g3")
        if stage == 3:
            ball(im, sx, BASE - h - 1, 2.2, 2, ("d5", "d6", "white", "white", "white", "white"))
        else:
            put(im, sx, BASE - h + 2, "g4")
    return dark_outline(im)


def melon(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 7, 1.6)
    for x in range(2, 14):
        put(im, x, BASE, "g1")
    leaf(im, 2, BASE - 3, 1)
    leaf(im, 14, BASE - 4, -1)
    r = 3 if stage == 2 else 6
    ball(im, 8, BASE - r + 0.5, r + 1, r, ("g0", "g1", "g2", "g3", "g4", "g5"))
    if stage == 3:
        for sx in (5, 8, 11):
            for y in range(BASE - 10, BASE):
                if get(im, sx, y)[3]:
                    put(im, sx, y, "g4" if y % 2 else "g5")
        dark_outline(im)
        for x, y, a in ((1, BASE - 7, 120), (15, BASE - 5, 120), (12, BASE - 12, 160), (3, BASE - 11, 90)):
            if get(im, x, y)[3] == 0:
                put(im, x, y, "g5", a)
        return im
    return dark_outline(im)


def corn(stage):
    im = new(CW, CH)
    shadow(im, 8, BASE + 0.5, 5, 1.3)
    h = 12 if stage == 2 else 18
    for sx in (6, 10):
        _stem(im, sx, BASE, h)
        leaf(im, sx - 1, BASE - 6, -1)
        leaf(im, sx + 1, BASE - 10, 1)
    if stage == 3:
        for sx in (6, 10):
            for k in range(5):
                put(im, sx + 1, BASE - 12 + k, "v2" if k % 2 else "v3")
                put(im, sx + 2, BASE - 12 + k, "v1")
            put(im, sx + 1, BASE - 13, "y4")  # silk
            put(im, sx, BASE - h, "y3")  # tassel
            put(im, sx - 1, BASE - h - 1, "y4")
    return dark_outline(im)


# id, seed colour, sprout colours, ripe builder
NEW_CROPS = [
    ("ashcarrot", "o3", ("g2", "g3", "g5"), carrot),
    ("suncrown", "y2", ("g1", "g2", "g4"), sunflower),
    ("bloodberry", "b3", ("g1", "g2", "g4"), berry_bush),
    ("ironbean", "n2", ("g1", "g3", "g4"), beans),
    ("frostcabbage", "f3", ("f0", "f1", "f3"), cabbage),
    ("emberpepper", "b2", ("g1", "g2", "g4"), pepper),
    ("cottonpuff", "white", ("g2", "g3", "g5"), cotton),
    ("glowmelon", "g5", ("g1", "g2", "g5"), melon),
    ("stormcorn", "v3", ("g1", "g3", "g5"), corn),
]


def crop_sprites():
    s = {}
    for cid, seed, sp, fn in NEW_CROPS:
        s[cid + "_0"] = seed_stage(seed)
        s[cid + "_1"] = sprout(*sp)
        s[cid + "_2"] = fn(2)
        s[cid + "_3"] = fn(3)
    return s
