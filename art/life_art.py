"""Living farm and the new HUD art: farmer, chickens, crow, butterflies,
bold dock icons, round side buttons, level shield, dew drop.
Uses the drawing helpers and palette of generate_sprites.py."""
from generate_sprites import P, ball, dark_outline, line, new, put, rect, shadow

P.update({
    # cloth blues for the farmer's overalls
    "b1": "#2c3f73", "b2": "#3b5a9a", "b3": "#5b80c4", "b4": "#8fb0e6",
    # skin
    "k1": "#b8714f", "k2": "#e09a6e", "k3": "#f6c39a",
    # bright dock UI
    "u0": "#5a3420", "u1": "#7b4a2c", "u2": "#a26a3c",  # dock wood
    "q0": "#b98a4c", "q1": "#e7c98d", "q2": "#f8e7bd", "q3": "#fff8e4",  # button parchment
    "x0": "#7d1f1a", "x1": "#b8382a", "x2": "#e2603a", "x3": "#ff9a52", "x4": "#ffd08a",  # raid button
})


# ------------------------------------------------------------------ farm life
def farmer(frame):
    """Farmer in a straw hat and blue overalls carrying a watering can.
    16x24, two walk frames."""
    im = new(16, 24)
    step = 1 if frame else 0
    # legs
    rect(im, 6, 18, 7, 21 - step, "b1")
    rect(im, 9, 18, 10, 20 + step, "b1")
    rect(im, 5, 22 - step, 7, 22 - step, "s1")
    rect(im, 9, 21 + step, 11, 21 + step, "s1")
    # shirt and overalls
    rect(im, 5, 11, 11, 17, "c2")
    rect(im, 5, 11, 7, 17, "c3")
    rect(im, 6, 13, 10, 18, "b2")
    rect(im, 6, 13, 7, 18, "b3")
    put(im, 6, 12, "b2")
    put(im, 10, 12, "b2")
    put(im, 7, 14, "y3")
    put(im, 9, 14, "y3")
    # arms; the right one holds the can
    rect(im, 4, 12, 4, 15 + step, "c3")
    put(im, 4, 16 + step, "k2")
    rect(im, 12, 12, 12, 15, "c1")
    put(im, 12, 16, "k2")
    # watering can
    rect(im, 12, 16, 15, 19, "m1")
    rect(im, 12, 16, 13, 18, "m2")
    put(im, 12, 16, "m3")
    line(im, 15, 17, 15, 15, "m1")
    put(im, 14, 15, "d5")
    # head
    ball(im, 8, 8, 2.8, 2.8, ("k1", "k1", "k2", "k2", "k3", "k3"))
    put(im, 9, 8, "ink")
    put(im, 10, 9, "k1")
    # straw hat
    rect(im, 3, 5, 13, 6, "y2")
    rect(im, 3, 5, 8, 5, "y4")
    rect(im, 5, 2, 11, 5, "y3")
    rect(im, 5, 2, 7, 4, "y4")
    rect(im, 5, 4, 11, 4, "c2")
    shadow(im, 8, 23, 5, 1, 90)
    return dark_outline(im)


def chicken(frame):
    """White hen pecking: 10x9, frame 1 has the head down."""
    im = new(10, 9)
    ball(im, 5, 5, 3.6, 2.8, ("d4", "d5", "d6", "white", "white", "white"))
    rect(im, 1, 3, 2, 4, "d6")  # tail
    put(im, 1, 2, "white")
    hx, hy = (8, 2) if frame == 0 else (8, 5)
    ball(im, hx, hy, 1.4, 1.4, ("d6", "white", "white", "white", "white", "white"))
    put(im, hx, hy - 2, "r2")  # comb
    put(im, hx + 1, hy - 2, "r2")
    put(im, hx + 2, hy, "y3")  # beak
    put(im, hx + 1, hy, "ink")
    put(im, 4, 8, "y2")
    put(im, 6, 8, "y2")
    return dark_outline(im)


def crow():
    """Crow perched, 10x8, sits on the scarecrow's arm."""
    im = new(10, 8)
    ball(im, 5, 4, 3.2, 2.4, ("ink", "d0", "d0", "d1", "d2", "d3"))
    ball(im, 7, 2, 1.6, 1.5, ("ink", "d0", "d1", "d1", "d2", "d2"))
    put(im, 9, 2, "y2")
    put(im, 7, 1, "y4")
    line(im, 0, 5, 2, 4, "d0")
    put(im, 4, 7, "y1")
    put(im, 6, 7, "y1")
    return im


def butterfly(frame):
    im = new(5, 4)
    if frame == 0:
        rect(im, 0, 0, 1, 1, "o4")
        rect(im, 3, 0, 4, 1, "o4")
        put(im, 0, 2, "o3")
        put(im, 4, 2, "o3")
    else:
        rect(im, 1, 0, 1, 2, "o4")
        rect(im, 3, 0, 3, 2, "o4")
    rect(im, 2, 0, 2, 3, "ink")
    return im


# ------------------------------------------------------------------ dock icons (18x18, bold)
def icon_barn():
    im = new(18, 18)
    for y in range(1, 8):  # gambrel roof
        half = 2 + (y - 1) * 1.15
        for x in range(int(9 - half), int(9 + half) + 1):
            put(im, x, y, "c3" if x < 9 else "c2")
    line(im, 2, 7, 16, 7, "white")
    rect(im, 2, 8, 15, 16, "c2")
    rect(im, 2, 8, 8, 16, "c3")
    rect(im, 5, 10, 12, 16, "w1")
    rect(im, 5, 10, 12, 10, "white")
    rect(im, 5, 10, 5, 16, "white")
    rect(im, 12, 10, 12, 16, "white")
    line(im, 6, 11, 11, 16, "white")
    line(im, 11, 11, 6, 16, "white")
    rect(im, 8, 3, 9, 5, "y4")
    put(im, 8, 3, "y5")
    return dark_outline(im, 0.3)


def icon_orders():
    im = new(18, 18)
    rect(im, 3, 12, 4, 17, "w1")
    rect(im, 13, 12, 14, 17, "w1")
    rect(im, 1, 2, 16, 12, "w2")
    rect(im, 1, 2, 16, 3, "w4")
    rect(im, 1, 11, 16, 12, "w1")
    for (x0, y0, c) in ((3, 4, "white"), (10, 3, "q2")):
        rect(im, x0, y0, x0 + 4, y0 + 6, c)
        for yy in range(y0 + 2, y0 + 6, 2):
            line(im, x0 + 1, yy, x0 + 3, yy, "d3")
        put(im, x0 + 2, y0, "r2")
    put(im, 15, 9, "y3")  # coin on the board
    return dark_outline(im, 0.3)


def icon_hammer():
    im = new(18, 18)
    for i in range(11):  # handle
        put(im, 3 + i, 15 - i, "w4")
        put(im, 4 + i, 15 - i, "w2")
        put(im, 4 + i, 16 - i, "w1")
    for i in range(-3, 5):  # steel head across the handle
        for j in range(0, 4):
            c = "d6" if i < 0 else "d4"
            if j == 0:
                c = "white" if i < 1 else "d5"
            put(im, 12 + i + j, 5 + i - j + 1, c)
            put(im, 13 + i + j, 5 + i - j + 1, c)
    return dark_outline(im, 0.3)


def icon_storage():
    """Crate with sacks of grain on top."""
    im = new(18, 18)
    rect(im, 2, 9, 15, 16, "w2")
    rect(im, 2, 9, 15, 9, "w4")
    for x in (2, 8, 15):
        rect(im, x, 9, x, 16, "w1")
    line(im, 3, 15, 7, 10, "w3")
    line(im, 9, 15, 14, 10, "w3")
    ball(im, 6, 6, 3.4, 3.2, ("s2", "s3", "s4", "s5", "w4", "q1"))
    ball(im, 12, 6, 3.2, 3.0, ("s2", "s3", "s4", "s4", "s5", "w4"))
    for x in (5, 6, 7):  # grain spilling from the open sack
        put(im, x, 3, "y3")
    put(im, 6, 2, "y4")
    put(im, 12, 3, "s1")
    return dark_outline(im, 0.3)


def icon_raid():
    """Crossed pitchfork and sickle over a torn banner: the raid button."""
    im = new(22, 22)
    for i in range(16):  # pitchfork shaft
        put(im, 3 + i, 18 - i, "w4")
        put(im, 4 + i, 18 - i, "w2")
    for k in range(-2, 3):  # crossbar across the shaft
        put(im, 18 + k, 4 + k, "d5")
    for t in (-2, 0, 2):  # three tines along the shaft
        for k in range(1, 5):
            put(im, 18 + t + k, 4 + t - k, "d6" if k < 4 else "white")
    for i in range(14):  # sickle handle crossing
        put(im, 18 - i, 18 - i, "w1" if i < 5 else "w3")
    for a in range(10):  # sickle blade arc
        import math
        ang = math.pi * (0.9 + a * 0.11)
        x = 7 + math.cos(ang) * 5.5
        y = 7 + math.sin(ang) * 5.5
        put(im, x, y, "white" if a % 3 else "d6")
        put(im, x + 1, y, "d5")
    return dark_outline(im, 0.3)


# ------------------------------------------------------------------ small HUD icons (14x14)
def icon_mail():
    im = new(14, 14)
    rect(im, 1, 3, 12, 11, "q2")
    rect(im, 1, 3, 12, 3, "q3")
    line(im, 1, 3, 6, 8, "q0")
    line(im, 12, 3, 7, 8, "q0")
    put(im, 6, 8, "r2")
    put(im, 7, 8, "r2")
    put(im, 6, 9, "r1")
    put(im, 7, 9, "r1")
    return dark_outline(im, 0.3)


def icon_tasks():
    im = new(14, 14)
    rect(im, 2, 1, 11, 12, "q2")
    rect(im, 2, 1, 11, 2, "q0")
    for y in (4, 7, 10):
        put(im, 4, y, "g3")
        line(im, 6, y, 9, y, "d3")
    return dark_outline(im, 0.3)


def icon_calendar():
    im = new(14, 14)
    rect(im, 1, 2, 12, 12, "q3")
    rect(im, 1, 2, 12, 4, "x1")
    put(im, 4, 1, "d3")
    put(im, 9, 1, "d3")
    for y in (6, 8, 10):
        for x in (3, 6, 9):
            put(im, x, y, "d4")
    rect(im, 8, 9, 10, 11, "x2")
    return dark_outline(im, 0.3)


def icon_dew():
    """Rosa: the premium dew drop."""
    im = new(12, 14)
    for y in range(1, 13):
        w = 0.6 + (y - 1) * 0.9 if y < 7 else 5 - (y - 7) ** 2 * 0.12
        for x in range(12):
            if abs(x + 0.5 - 6) <= w:
                put(im, x, y, "m2" if x < 6 else "m1")
    ball(im, 6, 9, 3.6, 3.2, ("m0", "m1", "m2", "m3", "m4", "m5"))
    put(im, 4, 7, "white")
    put(im, 4, 8, "m5")
    return dark_outline(im, 0.3)


def icon_sickle():
    import math
    im = new(12, 12)
    for a in range(12):
        ang = math.pi * (1.0 + a * 0.1)
        put(im, 6 + math.cos(ang) * 4.5, 5 + math.sin(ang) * 4.5, "white")
    line(im, 6, 6, 10, 10, "w3")
    return dark_outline(im, 0.3)


def level_shield():
    """Level badge: gold-rimmed shield, 18x20."""
    im = new(18, 20)
    for y in range(20):
        if y < 12:
            half = 8
        else:
            half = int(8 - (y - 12) * 1.05)
        for x in range(9 - half, 9 + half):
            edge = x in (9 - half, 9 + half - 1) or y in (0, 19)
            put(im, x, y, "y2" if edge else ("b2" if x < 9 else "b1"))
    for x in range(2, 16):
        put(im, x, 1, "y4")
    return dark_outline(im, 0.3)


def life_sprites():
    return {
        "unit_farmer_0": farmer(0), "unit_farmer_1": farmer(1),
        "life_chicken_0": chicken(0), "life_chicken_1": chicken(1),
        "life_crow": crow(),
        "life_butterfly_0": butterfly(0), "life_butterfly_1": butterfly(1),
        "dock_barn": icon_barn(), "dock_orders": icon_orders(), "dock_workshop": icon_hammer(),
        "dock_storage": icon_storage(), "dock_raids": icon_raid(),
        "hud_mail": icon_mail(), "hud_tasks": icon_tasks(), "hud_calendar": icon_calendar(),
        "hud_dew": icon_dew(), "hud_sickle": icon_sickle(), "hud_level": level_shield(),
    }
