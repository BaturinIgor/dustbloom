"""Working buildings: well, workshop, forge, order board, watchtower.
Three looks each (levels 1-10, 11-20, 21-30) plus an empty building site.
Uses the drawing helpers and palette of generate_sprites.py."""
from generate_sprites import dark_outline, line, new, put, rect

# roof ramps per tier: light, mid, dark
ROOF = [("w3", "w2", "w1"), ("c3", "c2", "c1"), ("o3", "o2", "o1")]
TRIM = ["w1", "c1", "y2"]


def _planks(im, x0, y0, x1, y1, step=4):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = "w3" if x < (x0 + x1) // 2 else "w2"
            if (x - x0) % step == 0:
                c = "w1"
            put(im, x, y, c)


def _stones(im, x0, y0, x1, y1, light="d4", mid="d3", dark="d2"):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            brick = ((x + (2 if (y // 3) % 2 else 0)) // 4) % 2
            c = (light if brick else mid) if x < (x0 + x1) // 2 else (mid if brick else dark)
            if y % 3 == 0:
                c = "d1"
            put(im, x, y, c)


def _roof(im, x0, x1, top, bottom, tier, overhang=2):
    """Gable roof: rows widen from the ridge down."""
    lit, mid, dark = ROOF[tier]
    cx = (x0 + x1) / 2
    for y in range(top, bottom + 1):
        half = (x1 - x0) / 2 + overhang * (y - top) / max(1, bottom - top)
        half = min(half, (x1 - x0) / 2 + overhang)
        left, right = int(cx - half), int(cx + half)
        for x in range(left, right + 1):
            c = lit if x < cx else mid
            if (y - top) % 3 == 2:
                c = dark
            put(im, x, y, c)
    line(im, x0 - overhang, bottom, x1 + overhang, bottom, TRIM[tier])


def _flag(im, x, y, tier):
    rect(im, x, y, x, y + 9, "w0")
    col = ["r2", "m2", "y3"][tier]
    rect(im, x + 1, y, x + 5, y + 3, col)
    put(im, x + 5, y + 3, "ink", 0)


def well(tier):
    im = new(16, 24)
    # posts and roof
    rect(im, 2, 6, 2, 17, "w1")
    rect(im, 13, 6, 13, 17, "w1")
    _roof(im, 3, 12, 1, 6, tier, overhang=2)
    line(im, 3, 9, 12, 9, "w0")  # crank axle
    rect(im, 7, 10, 8, 13, "d2")  # rope
    rect(im, 6, 13, 9, 15, "w2")  # bucket
    put(im, 6, 13, "w4")
    # stone ring
    if tier == 0:
        _stones(im, 1, 16, 14, 22)
    else:
        _stones(im, 1, 16, 14, 22, "d5", "d4", "d3")
    rect(im, 3, 16, 12, 17, "m1")  # water
    put(im, 5, 16, "m3")
    if tier == 2:  # gold trim and flowers
        line(im, 1, 16, 14, 16, "y2")
        for x, c in ((0, "r2"), (15, "y3"), (1, "g4"), (14, "g4")):
            put(im, x, 22, c)
            put(im, x, 21, "g3")
    return dark_outline(im)


def workshop(tier):
    im = new(32, 32)
    if tier >= 1:
        _stones(im, 3, 26, 28, 30)
    _planks(im, 3, 14, 28, 30 if tier == 0 else 25)
    # wide open doorway with a scarecrow frame inside
    rect(im, 10, 18, 21, 30, "w0")
    rect(im, 15, 19, 16, 29, "w2")
    rect(im, 12, 21, 19, 21, "w2")
    rect(im, 14, 19, 17, 20, "y2")  # straw head
    # saw and hammer on the wall
    line(im, 4, 17, 8, 17, "d5")
    line(im, 4, 18, 8, 18, "d4")
    rect(im, 24, 17, 24, 21, "w1")
    rect(im, 23, 17, 25, 18, "d3")
    _roof(im, 3, 28, 4, 13, tier, overhang=2)
    if tier >= 1:  # little window in the gable
        rect(im, 14, 8, 17, 11, "w0")
        rect(im, 15, 9, 16, 10, "y4")
    if tier == 2:
        _flag(im, 27, 0, tier)
    return dark_outline(im)


def forge(tier):
    im = new(32, 32)
    _stones(im, 3, 13, 26, 30, *(("d4", "d3", "d2") if tier < 2 else ("d5", "d4", "d3")))
    # chimney with glow
    rect(im, 21, 1, 25, 12, "d2")
    rect(im, 21, 1, 25, 2, "d1")
    put(im, 23, 0, "o3")
    # furnace mouth
    rect(im, 8, 19, 17, 30, "s0")
    rect(im, 9, 22, 16, 30, "o2")
    rect(im, 10, 24, 15, 30, "o3")
    rect(im, 11, 26, 14, 30, "y3")
    for x in range(8, 18):  # arch
        put(im, x, 19, "d1")
    _roof(im, 2, 20, 6, 13, tier, overhang=1)
    # anvil outside
    rect(im, 22, 25, 29, 26, "d2")
    rect(im, 24, 27, 27, 30, "d1")
    line(im, 22, 25, 29, 25, "d4")
    if tier >= 1:  # bellows
        rect(im, 18, 26, 20, 29, "s3")
        put(im, 19, 27, "s5")
    if tier == 2:
        line(im, 2, 13, 26, 13, "y2")
        _flag(im, 3, 0, tier)
    return dark_outline(im)


def order_board(tier):
    im = new(16, 24)
    rect(im, 2, 4, 2, 23, "w1")
    rect(im, 13, 4, 13, 23, "w1")
    rect(im, 1, 6, 14, 16, "w2" if tier < 2 else "w3")
    line(im, 1, 6, 14, 6, "w1")
    line(im, 1, 16, 14, 16, "w1")
    papers = [(3, 8), (8, 8), (4, 12)] + ([(9, 12)] if tier >= 1 else []) + ([(11, 9)] if tier == 2 else [])
    for x, y in papers:
        rect(im, x, y, x + 3, y + 3, "white")
        line(im, x + 1, y + 1, x + 2, y + 1, "d3")
        line(im, x + 1, y + 2, x + 2, y + 2, "d4")
        put(im, x + 1, y, "r2")  # pin
    if tier >= 1:  # little roof
        lit, mid, dark = ROOF[tier]
        rect(im, 0, 3, 15, 4, mid)
        line(im, 1, 2, 14, 2, lit)
        line(im, 0, 5, 15, 5, dark)
    if tier == 2:
        put(im, 7, 1, "y3")
        put(im, 8, 1, "y4")
    return dark_outline(im)


def watchtower(tier):
    im = new(16, 40)
    # legs with cross braces
    for x in (2, 13):
        rect(im, x, 16, x, 39, "w1")
    line(im, 3, 22, 12, 32, "w2")
    line(im, 12, 22, 3, 32, "w2")
    if tier >= 1:  # stone base
        _stones(im, 1, 33, 14, 39)
    # cabin
    _planks(im, 1, 10, 14, 16, step=3)
    rect(im, 4, 11, 11, 13, "w0")  # lookout slit
    rect(im, 5, 12, 10, 12, "y3" if tier == 2 else "d2")
    line(im, 0, 16, 15, 16, "w0")
    # roof
    lit, mid, dark = ROOF[tier]
    for y in range(3, 10):
        half = (y - 3) + 2
        for x in range(8 - half, 8 + half):
            put(im, x, y, lit if x < 8 else mid)
    line(im, 0, 9, 15, 9, dark)
    if tier >= 1:
        _flag(im, 8, 0 if tier == 2 else 1, tier)
    return dark_outline(im)


def building_site():
    """Pegs, rope and a little sign: a building that is not built yet."""
    im = new(16, 16)
    for x, y in ((1, 9), (14, 9), (1, 14), (14, 14)):
        rect(im, x, y, x, y + 1, "w1")
        put(im, x, y - 1, "w3")
    line(im, 1, 9, 14, 9, "y2")
    line(im, 1, 14, 14, 14, "y2")
    line(im, 1, 9, 1, 14, "y1")
    line(im, 14, 9, 14, 14, "y1")
    rect(im, 7, 3, 7, 12, "w1")  # sign post
    rect(im, 4, 2, 11, 6, "w3")
    line(im, 4, 6, 11, 6, "w1")
    rect(im, 6, 3, 9, 4, "w0")  # hammer mark
    return dark_outline(im)


def icon_settings():
    """16x16 gear for the settings button."""
    import math
    im = new(16, 16)
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = 6.8 if (math.cos(a * 8) > 0.2) else 5.2
            if r <= tooth and r > 2.2:
                put(im, x, y, "d5" if dx + dy < 0 else "d3")
            elif r <= 2.2:
                pass
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        put(im, x, y, "ink", 0)
    return dark_outline(im)


DRAW = {"well": well, "workshop": workshop, "forge": forge, "order_board": order_board, "watchtower": watchtower}


def building_sprites():
    from generate_sprites import cast_shadow
    s = {"bld_site": building_site(), "icon_settings": icon_settings()}
    for bid, fn in DRAW.items():
        for t in range(3):
            im = fn(t)
            s["bld_%s_%d" % (bid, t)] = im
            s["shadow_bld_%s_%d" % (bid, t)] = cast_shadow(im)
    return s
