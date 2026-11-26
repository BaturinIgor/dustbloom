"""Storage (Склад) sprites: the storage icon, speedup hourglasses and chests.
Uses the drawing helpers and palette of generate_sprites.py."""
from generate_sprites import dark_outline, line, new, put, rect

# speedup frame colours by target: any = gold, recruit = red, grow = green, build = blue
SPEED_COLS = {
    "any": ("y1", "y2", "y3"),
    "recruit": ("c1", "c2", "c3"),
    "grow": ("g1", "g2", "g4"),
    "build": ("m0", "m1", "m2"),
}


def hourglass(target):
    dark, mid, light = SPEED_COLS[target]
    im = new(16, 16)
    rect(im, 3, 1, 12, 2, mid)       # top cap
    rect(im, 3, 13, 12, 14, mid)     # bottom cap
    line(im, 3, 1, 12, 1, light)
    line(im, 3, 13, 12, 13, light)
    for y in (3, 12):                # posts
        put(im, 4, y, dark)
        put(im, 11, y, dark)
    for i in range(4):               # glass: two triangles
        y = 3 + i
        for x in range(5 + i, 11 - i):
            put(im, x, y, "m4" if x == 5 + i else "m5")
        y = 12 - i
        for x in range(5 + i, 11 - i):
            put(im, x, y, "m4" if x == 5 + i else "m5")
    for x in range(6, 10):           # sand left in the top
        put(im, x, 4, "y3")
    for x in range(7, 9):
        put(im, x, 5, "y3")
    put(im, 7, 7, "y3")              # falling grain
    put(im, 8, 8, "y3")
    for x in range(6, 10):           # pile at the bottom
        put(im, x, 11, "y2")
    for x in range(5, 11):
        put(im, x, 12, "y2")
    put(im, 13, 3, "white")          # glint
    return dark_outline(im)


def chest(wood, band, lock):
    im = new(16, 16)
    rect(im, 1, 4, 14, 7, wood[2])   # lid
    line(im, 2, 3, 13, 3, wood[2])
    line(im, 2, 4, 13, 4, wood[3])
    rect(im, 1, 8, 14, 14, wood[1])  # body
    rect(im, 1, 8, 14, 8, wood[0])   # seam shadow
    for x in (3, 12):                # metal bands
        rect(im, x, 3, x, 14, band[0])
        put(im, x, 4, band[1])
    rect(im, 1, 14, 14, 14, wood[0])
    rect(im, 6, 7, 9, 10, lock[0])   # lock plate
    put(im, 6, 7, lock[1])
    put(im, 7, 9, "ink")
    put(im, 8, 9, "ink")
    return dark_outline(im)


def icon_storage():
    """Storage building: a crate with a hourglass sticker, stacked on a sack."""
    im = new(16, 16)
    rect(im, 1, 9, 9, 15, "y2")      # grain sack
    rect(im, 1, 9, 3, 15, "y3")
    put(im, 5, 8, "y1")
    rect(im, 5, 3, 15, 13, "w2")     # crate
    rect(im, 5, 3, 15, 3, "w3")
    line(im, 5, 3, 15, 13, "w3")
    line(im, 15, 3, 5, 13, "w1")
    rect(im, 5, 3, 5, 13, "w3")
    rect(im, 9, 6, 11, 10, "y4")     # hourglass sticker
    put(im, 10, 8, "y1")
    return dark_outline(im)


def item_sprites():
    s = {"icon_storage": icon_storage()}
    for t in SPEED_COLS:
        s["item_speed_" + t] = hourglass(t)
    s["item_chest_wood"] = chest(("w0", "w1", "w2", "w3"), ("d3", "d5"), ("d4", "d6"))
    s["item_chest_iron"] = chest(("d0", "d1", "d3", "d4"), ("d5", "d6"), ("y2", "y4"))
    s["item_chest_gold"] = chest(("y0", "y1", "y2", "y3"), ("o2", "o4"), ("y4", "y5"))
    return s
