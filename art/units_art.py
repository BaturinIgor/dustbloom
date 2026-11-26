"""Stage-1 sprites: combat scarecrows, raid enemies and HUD action icons.
Uses the drawing helpers and palette of generate_sprites.py."""
import math

from generate_sprites import P, ball, dark_outline, line, new, put, rect, shadow


def _body(im, cx, top, h, half0, cols, belt="y2"):
    """Coat: a widening trapezoid with a lit left edge and a rope belt."""
    lit, mid, dark = cols
    for i in range(h):
        y = top + i
        half = half0 + i // 3
        for x in range(cx - half, cx + half):
            put(im, x, y, lit if x == cx - half else (mid if x < cx else dark))
    by = top + h // 2
    for x in range(cx - half0 - h // 6, cx + half0 + h // 6):
        put(im, x, by, belt if x % 2 else "y1")
    for x in range(cx - half0 - 1, cx + half0 + 2, 2):  # straw hem
        put(im, x, top + h, "y3")


def _pole(im, cx, y0, y1):
    for y in range(y0, y1):
        put(im, cx, y, "w2")
        put(im, cx + 1, y, "w1")


def straw_guard():
    """Cheap, sturdy line holder: sack head, wooden shield, pitchfork."""
    im = new(24, 32)
    _pole(im, 12, 22, 30)
    _body(im, 12, 13, 9, 4, ("y4", "y3", "y2"), belt="w2")
    # arms
    for x in range(5, 20):
        put(im, x, 14, "w3")
    # pitchfork on the right
    line(im, 20, 4, 20, 27, "w2")
    for tx in (18, 20, 22):
        line(im, tx, 2, tx, 5, "d6")
    line(im, 18, 5, 22, 5, "d5")
    # round shield on the left
    ball(im, 6, 19, 4.2, 4.6, ("w0", "w1", "w2", "w3", "w4", "w4"))
    put(im, 6, 19, "d6")
    put(im, 5, 18, "white")
    # sack head with ember eyes
    ball(im, 12, 9, 3.8, 3.6, ("y0", "y1", "y2", "y3", "y4", "y5"))
    for ex in (10, 14):
        put(im, ex, 9, "o4")
        put(im, ex, 10, "o1")
        put(im, ex - 1, 9, "y0")
    for x in range(10, 15):
        put(im, x, 12, "y1" if x % 2 else "y0")
    # straw tuft
    for x, y in ((11, 4), (12, 4), (13, 5), (10, 5)):
        put(im, x, y, "y4")
    shadow(im, 12, 30.5, 7, 1.4, 90)
    return dark_outline(im)


def pumpkin_brute():
    """Heavy hitter: glowing jack-o'-lantern head, broad coat, spiked club."""
    im = new(24, 32)
    _pole(im, 12, 23, 30)
    _body(im, 12, 13, 10, 5, ("c3", "c2", "c1"), belt="w3")
    for x in range(3, 21):
        put(im, x, 14, "w3")
        put(im, x, 15, "w1")
    # club, raised on the right
    for i in range(10):
        put(im, 20 + i // 4, 15 - i, "w3")
        put(im, 21 + i // 4, 15 - i, "w1")
    ball(im, 23, 4, 2.2, 3, ("w0", "w1", "w2", "w3", "w4", "w4"))
    for sx, sy in ((21, 3), (23, 1), (23, 7)):
        put(im, sx, sy, "d6")
    # pumpkin head
    ball(im, 12, 8, 5.6, 4.6, ("o0", "o1", "o2", "o3", "o4", "o5"))
    for y in range(4, 13):
        if y not in (4, 12):
            put(im, 10, y, "o1")
            put(im, 14, y, "o1")
    rect(im, 11, 2, 12, 3, "g2")  # stalk
    put(im, 13, 2, "g4")
    # carved face, lit from inside
    for x, y in ((9, 7), (10, 7), (14, 7), (15, 7)):
        put(im, x, y, "y5")
    for x in range(9, 16):
        put(im, x, 10, "y4" if x % 2 else "y2")
    shadow(im, 12, 30.5, 8, 1.4, 90)
    return dark_outline(im)


def moon_witch():
    """Glass cannon: moon-turnip face, tall hat, staff with a moon crystal."""
    im = new(24, 32)
    _pole(im, 12, 23, 30)
    _body(im, 12, 14, 9, 3, ("m2", "m1", "m0"), belt="m4")
    for x in range(6, 18):
        put(im, x, 15, "w3")
    # staff on the left with a glowing crystal
    line(im, 4, 7, 4, 28, "w2")
    for (x, y, c) in ((4, 3, "m5"), (3, 4, "m4"), (5, 4, "m4"), (4, 4, "m5"), (4, 5, "m3"), (3, 5, "m3"), (5, 5, "m2"), (4, 6, "m2")):
        put(im, x, y, c)
    for (x, y) in ((2, 2), (6, 2), (1, 5), (7, 6)):
        put(im, x, y, "m4", 150)
    # turnip head
    ball(im, 12, 11, 3.6, 3.2, ("m1", "m2", "m3", "m4", "m5", "white"))
    put(im, 10, 11, "r2")
    put(im, 14, 11, "r2")
    put(im, 12, 13, "m1")
    # pointed hat, bent tip
    for y in range(1, 9):
        half = max(0, (y - 1) // 2)
        for x in range(12 - half, 13 + half):
            put(im, x, y, "d1" if x < 12 else "d0")
    put(im, 14, 1, "d1")
    put(im, 15, 2, "d0")
    for x in range(7, 18):
        put(im, x, 8, "d2" if x < 12 else "d1")
    for x in range(9, 16):
        put(im, x, 7, "m3")  # hat band
    shadow(im, 12, 30.5, 6, 1.4, 90)
    return dark_outline(im)


def dust_rat():
    im = new(16, 16)
    ball(im, 8, 10, 5.5, 3.6, ("d0", "d1", "d2", "d3", "d4", "d5"))
    ball(im, 3.5, 9, 2.4, 2.2, ("d1", "d2", "d3", "d4", "d5", "d6"))
    put(im, 3, 8, "r3")
    put(im, 1, 9, "r2")  # nose
    put(im, 4, 6, "r2")  # ear
    put(im, 5, 6, "r1")
    for i in range(5):
        put(im, 13 + i // 2, 11 - i // 2 + (i % 2), "r1")  # tail
    for x in (5, 10):
        put(im, x, 13, "d0")
    shadow(im, 8, 14.5, 6, 1.2, 80)
    return dark_outline(im)


def rust_bandit():
    im = new(16, 24)
    # legs
    rect(im, 5, 17, 6, 21, "s1")
    rect(im, 9, 17, 10, 21, "s1")
    # poncho
    for y in range(9, 17):
        half = 3 + (y - 9) // 2
        for x in range(8 - half, 8 + half):
            put(im, x, y, "o2" if x < 8 else "o1")
    for x in range(3, 13, 2):
        put(im, x, 16, "o3")
    # head with goggles and bandana
    ball(im, 8, 6, 3.2, 3.2, ("s1", "s2", "s3", "s4", "s5", "s5"))
    rect(im, 5, 5, 11, 5, "ink")
    put(im, 6, 5, "m3")
    put(im, 10, 5, "m3")
    rect(im, 5, 8, 11, 9, "r1")
    # rusty blade
    line(im, 13, 6, 13, 14, "o0")
    line(im, 14, 6, 14, 13, "o1")
    put(im, 13, 15, "w1")
    shadow(im, 8, 22.5, 5, 1.2, 80)
    return dark_outline(im)


def scrap_golem():
    im = new(32, 32)
    # legs
    rect(im, 9, 23, 13, 29, "d1")
    rect(im, 19, 23, 23, 29, "d1")
    # body of welded plates
    for y in range(9, 24):
        for x in range(6, 27):
            c = "d3" if x < 16 else "d2"
            if (x + y) % 7 == 0:
                c = "o1"  # rust streak
            put(im, x, y, c)
    for x in range(6, 27):
        put(im, x, 16, "d1")
    for x, y in ((8, 11), (24, 11), (8, 21), (24, 21)):
        put(im, x, y, "d6")  # rivets
    # arms
    rect(im, 1, 10, 5, 22, "d2")
    rect(im, 27, 10, 31, 22, "d1")
    rect(im, 0, 22, 5, 25, "o1")
    rect(im, 27, 22, 32, 25, "o0")
    # head with a single furnace eye
    rect(im, 11, 3, 21, 9, "d2")
    rect(im, 11, 3, 15, 9, "d3")
    ball(im, 16, 6, 2.2, 1.6, ("o2", "o3", "o4", "y4", "y5", "white"))
    shadow(im, 16, 30.5, 13, 1.4, 90)
    return dark_outline(im)


def icon_barn():
    im = new(16, 16)
    for y in range(2, 7):  # roof
        half = 2 + (y - 2) * 1.4
        for x in range(int(8 - half), int(8 + half) + 1):
            put(im, x, y, "c3" if x < 8 else "c2")
    rect(im, 2, 7, 13, 14, "c2")
    rect(im, 2, 7, 7, 14, "c3")
    rect(im, 5, 9, 10, 14, "w1")  # door
    line(im, 5, 9, 10, 14, "w3")
    line(im, 10, 9, 5, 14, "w3")
    rect(im, 7, 4, 8, 5, "y4")  # hay loft
    return dark_outline(im)


def icon_hammer():
    im = new(16, 16)
    for i in range(10):
        put(im, 4 + i, 13 - i, "w3")
        put(im, 5 + i, 13 - i, "w1")
    # square head across the handle
    for i in range(-3, 4):  # along (1, 1), across the handle
        for j in range(0, 3):  # thickness along the handle
            put(im, 11 + i + j, 5 + i - j, "d5" if i < 1 else "d3")
            put(im, 12 + i + j, 5 + i - j, "d5" if i < 1 else "d3")
    put(im, 8, 2, "white")
    return dark_outline(im)


def icon_swords():
    im = new(16, 16)
    for i in range(11):
        put(im, 2 + i, 2 + i, "d6")
        put(im, 13 - i, 2 + i, "d5")
    for (x, y) in ((3, 11), (4, 10), (11, 10), (12, 11)):
        put(im, x, y, "y2")
    for (x, y) in ((2, 13), (13, 13)):
        put(im, x, y, "w1")
    return dark_outline(im)


def stage1_sprites():
    return {
        "unit_straw_guard": straw_guard(),
        "unit_pumpkin_brute": pumpkin_brute(),
        "unit_moon_witch": moon_witch(),
        "enemy_dust_rats": dust_rat(),
        "enemy_rust_bandits": rust_bandit(),
        "enemy_scrap_golem": scrap_golem(),
        "icon_barn": icon_barn(),
        "icon_workshop": icon_hammer(),
        "icon_raid": icon_swords(),
    }
