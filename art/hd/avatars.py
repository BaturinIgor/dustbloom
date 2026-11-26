"""Preset player avatars: 32 x 32 px portraits in the game style, plus the
power icon. Original characters: farmers with different hats, hair and
skin, and a few unlockable specials (pumpkin head, crow, straw knight)."""
from .draw import ball, line, new, outline, put, rect
from . import palette as P

SKIN = [("#f6c8a0", "#d89a74"), ("#e8b088", "#c08060"), ("#c88a60", "#9a6040"),
        ("#a06a48", "#784a30"), ("#7a4a30", "#5a3420")]
HAIR = ["#3a2418", "#6a3a20", "#c88a40", "#e8d090", "#a02e2e", "#2a2a30", "#e8e8e0"]
BG = ["#5f8548", "#4e7ca8", "#b86a3c", "#8a5aa8", "#c8a040", "#4a8a80", "#a84a5a", "#667086"]

# (skin, hair, hat, shirt, bg, beard)
PRESETS = [
    (0, 1, "straw", "#4e7ca8", 0, False),
    (2, 0, "cap_red", "#5f8548", 1, False),
    (1, 2, "none", "#a84a5a", 2, False),
    (3, 5, "bandana", "#c8a040", 3, True),
    (0, 3, "flower", "#8a5aa8", 4, False),
    (4, 5, "straw", "#b86a3c", 5, False),
    (1, 4, "none", "#4a8a80", 6, False),
    (2, 6, "cap_blue", "#667086", 7, True),
]
SPECIAL = ["pumpkin", "crow", "knight", "witch"]
# level each avatar unlocks at (0 = from the start)
UNLOCK = [0] * len(PRESETS) + [10, 20, 30, 40]


def _bust(im, skin, hair, shirt, beard):
    s, sd = SKIN[skin]
    h = HAIR[hair]
    # shoulders / shirt
    for y in range(24, 32):
        half = 9 + (y - 24) * 0.9
        for x in range(32):
            if abs(x + 0.5 - 16) <= half:
                t = 0.6 - (x - 16) / 40
                put(im, x, y, shirt if t > 0.55 else _dark(shirt))
    rect(im, 14, 21, 17, 24, sd)  # neck
    # head
    for y in range(8, 23):
        for x in range(8, 24):
            if ((x + 0.5 - 16) / 7.2) ** 2 + ((y + 0.5 - 15) / 7.6) ** 2 <= 1:
                put(im, x, y, s if x < 19 else sd)
    put(im, 8, 15, sd)
    put(im, 23, 15, sd)
    # hair
    for y in range(7, 13):
        for x in range(8, 24):
            if ((x + 0.5 - 16) / 7.8) ** 2 + ((y + 0.5 - 13) / 6.2) ** 2 <= 1 and y < 12 - (1 if 12 < x < 20 else 0):
                put(im, x, y, h)
    for y in range(11, 17):
        put(im, 8, y, h)
        put(im, 23, y, h)
    # face
    for x in (13, 19):
        put(im, x, 15, "#2a1a12")
        put(im, x, 14, "#2a1a12")
    put(im, 12, 17, "#e88a80")
    put(im, 20, 17, "#e88a80")
    line(im, 15, 19, 17, 19, "#8a3a2a")
    if beard:
        for y in range(18, 23):
            for x in range(10, 22):
                if ((x + 0.5 - 16) / 6.2) ** 2 + ((y + 0.5 - 18) / 4.6) ** 2 <= 1 and y >= 18:
                    put(im, x, y, h)
        line(im, 15, 19, 17, 19, "#5a2a1a")


def _dark(c):
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % (int(r * 0.72), int(g * 0.72), int(b * 0.78))


def _hat(im, hat):
    if hat == "straw":
        for x in range(3, 29):
            put(im, x, 10, "#e8c46a")
            put(im, x, 11, "#b8903e")
        for y in range(3, 10):
            for x in range(9, 23):
                if abs(x + 0.5 - 16) < 5 + (y - 3) * 0.3:
                    put(im, x, y, "#f0d47a" if x < 17 else "#d0aa50")
        rect(im, 9, 8, 22, 9, "#c84a3e")
    elif hat in ("cap_red", "cap_blue"):
        c = "#c84a3e" if hat == "cap_red" else "#3e64a8"
        for y in range(4, 11):
            for x in range(8, 24):
                if ((x + 0.5 - 16) / 8) ** 2 + ((y + 0.5 - 10.5) / 6.5) ** 2 <= 1:
                    put(im, x, y, c if x < 18 else _dark(c))
        rect(im, 4, 10, 15, 11, _dark(c))
        put(im, 16, 4, "#f0e0c8")
    elif hat == "bandana":
        for y in range(6, 11):
            for x in range(8, 24):
                if ((x + 0.5 - 16) / 8.2) ** 2 + ((y + 0.5 - 11) / 5.4) ** 2 <= 1:
                    put(im, x, y, "#c8403e" if (x + y) % 5 else "#f0e0c8")
        rect(im, 23, 10, 26, 12, "#a8302e")
    elif hat == "flower":
        for (x, y, c) in ((10, 8, "#f08aa0"), (12, 7, "#f4f0e6"), (11, 9, "#f2d050")):
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                put(im, x + dx, y + dy, c)
            put(im, x, y, "#f2d050")


def farmer(i):
    skin, hair, hat, shirt, bg, beard = PRESETS[i]
    im = new(32, 32)
    _bg(im, BG[bg])
    _bust(im, skin, hair, shirt, beard)
    _hat(im, hat)
    return im


def _bg(im, c):
    for y in range(32):
        for x in range(32):
            t = (x + y) / 62
            put(im, x, y, c if t < 0.55 else _dark(c))


def special(kind):
    im = new(32, 32)
    if kind == "pumpkin":
        _bg(im, "#3c2a48")
        _bust(im, 0, 0, "#5a3a6e", False)
        ball(im, 16, 15, 9, 8, "pumpkin", lo=0.3, hi=0.95)
        for (x, y) in ((12, 13), (13, 13), (19, 13), (20, 13), (12, 12), (20, 12)):
            put(im, x, y, "#3a1408")
        line(im, 12, 18, 20, 18, "#3a1408")
        for x in (14, 18):
            put(im, x, 19, "#3a1408")
        rect(im, 15, 5, 16, 7, P.RAMPS["leaf"][2])
    elif kind == "crow":
        _bg(im, "#4e7ca8")
        ball(im, 16, 20, 10, 9, "cape", lo=0.05, hi=0.4)
        ball(im, 16, 13, 7, 7, "cape", lo=0.05, hi=0.45)
        for k in range(5):
            line(im, 21 + k, 13 + k // 2, 26, 15, "#f0a02e")
        put(im, 18, 11, "#ffe080")
        put(im, 13, 11, "#ffe080")
    elif kind == "knight":
        _bg(im, "#8a5a3a")
        _bust(im, 1, 2, "#7e8ca2", False)
        for y in range(5, 16):
            for x in range(8, 24):
                if ((x + 0.5 - 16) / 8.4) ** 2 + ((y + 0.5 - 14) / 9) ** 2 <= 1 and y < 16:
                    put(im, x, y, "#9aa8bc" if x < 17 else "#647086")
        rect(im, 9, 13, 22, 14, "#2e3242")
        for y in range(1, 6):  # straw plume
            put(im, 16 + (y % 2), y, "#f0d47a")
    elif kind == "witch":
        _bg(im, "#3c2a48")
        _bust(im, 0, 6, "#5a2a6e", False)
        for y in range(0, 11):
            half = 1 + y * 0.9
            for x in range(32):
                if abs(x + 0.5 - 17) <= half:
                    put(im, x, y, "#2e2240" if x < 18 else "#1e1630")
        rect(im, 4, 10, 28, 11, "#2e2240")
        put(im, 18, 3, "#ffe080")
    return im


def power_icon():
    """Crossed swords, 16 x 16."""
    im = new(16, 16)
    for k in range(11):
        put(im, 2 + k, 2 + k, "#dce4ec")
        put(im, 13 - k, 2 + k, "#dce4ec")
        put(im, 3 + k, 2 + k, "#8a98aa")
        put(im, 12 - k, 2 + k, "#8a98aa")
    for (x, y) in ((3, 10), (12, 10)):
        rect(im, x - 1, y, x + 1, y, "#c8a040")
    rect(im, 1, 12, 3, 14, "#7a4a28")
    rect(im, 12, 12, 14, 14, "#7a4a28")
    return outline(im, "#2e1a10")


def sprites():
    s = {}
    for i in range(len(PRESETS)):
        s["avatar_%d" % i] = outline(farmer(i), "#2e1a10")
    for k, kind in enumerate(SPECIAL):
        s["avatar_%d" % (len(PRESETS) + k)] = outline(special(kind), "#2e1a10")
    s["ui_power"] = power_icon()
    return s
