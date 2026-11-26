"""Усадьба (manor) sprites: six looks, one for every five manor levels.
Each look is 48x48 on the same 3x3-tile footprint as the old farmhouse.
Uses the drawing helpers and palette of generate_sprites.py."""
from generate_sprites import dark_outline, line, new, put, rect

# per tier: roof ramp (lit, mid, dark, accent), walls, extras
ROOFS = [
    ("y3", "y2", "y1", "y0"),   # 0 straw thatch
    ("c3", "c2", "c1", "r1"),   # 1 crimson shingles
    ("c3", "c2", "c1", "r1"),   # 2
    ("m2", "m1", "m0", "m1"),   # 3 slate blue
    ("m2", "m1", "m0", "m1"),   # 4
    ("o3", "o2", "o1", "y2"),   # 5 copper with gold trim
]


def _walls(im, tier):
    stone_to = {0: 44, 1: 44, 2: 38, 3: 38, 4: 26, 5: 26}[tier]  # stone below this row
    for y in range(24, 44):
        for x in range(5, 43):
            if y >= stone_to:  # stone courses
                brick = ((x + (3 if (y // 3) % 2 else 0)) // 6) % 2
                c = ("d4" if brick else "d3") if x < 24 else ("d3" if brick else "d2")
                if y % 3 == 0:
                    c = "d1"
            else:  # planks
                c = "w3" if x < 24 else "w2"
                if (x - 5) % 5 == 0:
                    c = "w1"
                elif (x - 5) % 5 == 1 and x < 24:
                    c = "w4"
                if tier == 0 and (x * 7 + y * 3) % 23 == 0:
                    c = "w0"  # cracks in the old planks
            put(im, x, y, c)
    if tier >= 4:  # timber frame over the stone
        for x in (5, 14, 33, 42):
            rect(im, x, 26, x, 43, "w1")
        line(im, 5, 26, 42, 26, "w1")


def _foundation(im, tier):
    for x in range(4, 44):
        put(im, x, 44, "d4" if (x // 3) % 2 else "d3")
        put(im, x, 45, "d2")
        put(im, x, 46, "d1")
    if tier >= 2:  # steps up to the door
        rect(im, 19, 44, 29, 45, "d5")
        rect(im, 18, 46, 30, 46, "d4")


def _door(im, tier):
    wood = "w1" if tier < 5 else "s3"
    rect(im, 20, 30, 28, 43, "w0")
    rect(im, 21, 31, 27, 43, wood)
    for y in range(31, 44):
        put(im, 24, y, "w0")
    put(im, 26, 37, "y4")
    if tier >= 3:  # arched top
        rect(im, 21, 29, 27, 30, "w0")
        rect(im, 22, 28, 26, 28, "w0")
    rect(im, 19, 29 if tier < 3 else 27, 29, 29 if tier < 3 else 27, "y2" if tier == 5 else "w4")
    if tier == 5:  # glowing sigil above the door: a golden ear of wheat
        for y in range(23, 27):
            put(im, 24, y, "y4")
        for (x, y) in ((23, 24), (25, 24), (23, 25), (25, 25)):
            put(im, x, y, "y3")


def _windows(im, tier):
    for i, wx in enumerate((8, 32)):
        rect(im, wx, 29, wx + 7, 36, "w0")
        boarded = tier == 0 and i == 1
        for y in range(30, 36):
            for x in range(wx + 1, wx + 7):
                put(im, x, y, ("w2" if (y % 2) else "w3") if boarded else ("y4" if y < 33 else "y3"))
        if boarded:
            line(im, wx + 1, 30, wx + 6, 35, "w1")
            continue
        put(im, wx + 1, 30, "y5")
        put(im, wx + 2, 30, "y5")
        for y in range(30, 36):
            put(im, wx + 4, y, "w0")
        for x in range(wx + 1, wx + 7):
            put(im, x, 33, "w0")
        if tier >= 1:  # flower boxes
            rect(im, wx - 1, 37, wx + 8, 38, "w1")
            for x in range(wx, wx + 8, 2):
                put(im, x, 36, "r2" if (x // 2) % 2 else "y4")
                put(im, x + 1, 36, "g3")
        if tier >= 3:  # shutters
            rect(im, wx - 2, 29, wx - 1, 36, "m1")
            rect(im, wx + 8, 29, wx + 9, 36, "m0")


def _roof(im, tier):
    lit, mid, dark, accent = ROOFS[tier]
    for y in range(4, 25):
        half = 14 + (y - 4) * 9 // 20
        for x in range(24 - half, 24 + half):
            if tier == 0:  # thatch: vertical straw strokes
                c = lit if x < 24 else mid
                if (x * 3 + y) % 5 == 0:
                    c = dark
                if y >= 23 and x % 2:
                    c = accent  # ragged hem
            else:
                row = (y - 4) // 3
                shift = 2 if row % 2 else 0
                c = mid if x < 24 else dark
                if (y - 4) % 3 == 2:
                    c = accent if x < 24 else dark
                elif (x + shift) % 4 == 0:
                    c = dark
                elif (y - 4) % 3 == 0 and x < 24:
                    c = lit
            put(im, x, y, c)
    ridge = ("w2", "w4", "w3") if tier < 5 else ("y1", "y4", "y3")
    for x in range(9, 39):
        put(im, x, 3, ridge[0])
        put(im, x, 2, ridge[1] if x < 24 else ridge[2])
    if tier == 0:  # a patch of old boards on the thatch
        rect(im, 28, 12, 33, 15, "w2")
        line(im, 28, 14, 33, 14, "w1")
    if tier >= 3:  # dormer window
        rect(im, 20, 9, 28, 17, "w1")
        rect(im, 21, 11, 27, 16, "w0")
        rect(im, 22, 12, 26, 15, "y4")
        put(im, 24, 12, "w0")
        put(im, 24, 13, "w0")
        for i in range(5):
            put(im, 20 + i, 9 - i // 2, lit)
            put(im, 28 - i, 9 - i // 2, dark)


def _chimney(im, tier):
    c = ("d3", "d4", "d1") if tier < 4 else ("c2", "c3", "c1")
    rect(im, 33, 0, 37, 8, c[0])
    rect(im, 32, 0, 38, 1, c[1])
    for y in range(2, 9):
        put(im, 37, y, c[2])
        put(im, 33, y, c[1])


def _extras(im, tier):
    if tier >= 2:  # lantern beside the door
        rect(im, 17, 31, 18, 34, "w0")
        put(im, 17, 32, "y4")
        put(im, 18, 32, "y5")
        put(im, 17, 33, "y3")
    if tier >= 3:  # weather vane on the ridge
        rect(im, 12, 0, 12, 2, "d1")
        line(im, 10, 0, 14, 0, "d4")
    if tier >= 4:  # tall banners on both corners, hanging pennants with a notch
        flag = ("c1", "c2", "c3") if tier == 4 else ("y1", "y3", "y4")
        for bx in (3, 44):
            rect(im, bx, 8, bx, 45, "w1")
            put(im, bx, 7, "y4")
            for y in range(10, 24):
                for dx in range(-1, 3) if bx < 24 else range(-2, 2):
                    x = bx + dx
                    if y >= 22 and dx in (0, 1 if bx < 24 else -1):
                        continue  # notch
                    put(im, x, y, flag[2] if dx == (-1 if bx < 24 else -2) else flag[1] if y % 4 else flag[0])
            for y in range(13, 19):  # emblem: a small ear of wheat
                put(im, bx + (1 if bx < 24 else -1), y, "y5" if tier == 5 else "y4")


def manor(tier):
    im = new(48, 48)
    _foundation(im, tier)
    _walls(im, tier)
    for x in range(5, 43):  # shadow under the eaves
        put(im, x, 24, "w0")
        put(im, x, 25, "w1")
    _door(im, tier)
    _windows(im, tier)
    _roof(im, tier)
    _chimney(im, tier)
    _extras(im, tier)
    return dark_outline(im)


def manor_sprites():
    from generate_sprites import cast_shadow
    s = {}
    for t in range(6):
        im = manor(t)
        s["prop_manor_%d" % t] = im
        s["shadow_manor_%d" % t] = cast_shadow(im)
    return s
