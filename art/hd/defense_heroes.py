"""Farm Defense scarecrow heroes, big and animated: living scarecrows on a
stake, facing the viewer, swinging their weapons up toward the storm.

Each hero has 2 idle frames and 3 attack frames (wind-up, strike, recover):
def_hero_<id>_idle_0..1, def_hero_<id>_atk_0..2. 66 x 72 px, 1 px = 1.5 pt.
Original designs."""
import math

from . import palette as P
from .draw import ball, glow, line, new, outline, put, rect

W, H = 66, 72
CX = 33
GROUND = 68

# pose per frame: body bob, lean (x shift of the upper body), right/left arm
# angles (degrees, 0 = straight down, 90 = sideways out, 180 = straight up)
POSES = {
    "idle_0": dict(bob=0, lean=0, r=55, l=55, sq=0),
    "idle_1": dict(bob=1, lean=0, r=50, l=58, sq=1),
    "atk_0": dict(bob=1, lean=-1, r=150, l=40, sq=1),   # wind-up
    "atk_1": dict(bob=-2, lean=2, r=105, l=70, sq=-1),  # strike
    "atk_2": dict(bob=0, lean=1, r=80, l=60, sq=0),     # recover
}
FRAMES = list(POSES)


def R(name):
    return P.RAMPS[name]


def _shadow(im):
    for y in range(GROUND - 3, GROUND + 3):
        for x in range(CX - 15, CX + 16):
            dx, dy = (x + 0.5 - CX) / 15, (y + 0.5 - GROUND) / 3
            if dx * dx + dy * dy <= 1:
                put(im, x, y, "#2a2014", 80)


def _mound(im):
    """Straw tuft at the foot of the stake."""
    ball(im, CX, GROUND - 2, 9, 3.4, "straw", lo=0.2, hi=0.8)
    for k in range(-8, 9, 2):
        h = 3 + (k * 7) % 3
        line(im, CX + k, GROUND - 2, CX + k + (1 if k > 0 else -1), GROUND - 2 - h, R("straw")[3 + (k // 2) % 2])


def _stake(im, top):
    w = R("wood")
    rect(im, CX - 1, top, CX + 1, GROUND - 3, w[3])
    rect(im, CX - 1, top, CX - 1, GROUND - 3, w[4])


def _limb(im, x0, y0, ang, length, width, ramp, lo=0.25, hi=0.75):
    """Thick shaded sleeve from the shoulder; returns the hand point."""
    a = math.radians(ang)
    dx, dy = math.sin(a), math.cos(a)
    for k in range(int(length) + 1):
        x, y = x0 + dx * k, y0 + dy * k
        ball(im, x, y, width, width, ramp, lo=lo, hi=hi)
    return x0 + dx * length, y0 + dy * length


def _cuff(im, x, y):
    """Straw sticking out of a sleeve: the scarecrow's hand."""
    s = R("straw")
    for k, (ox, oy) in enumerate(((-2, 1), (-1, 2), (0, 2), (1, 2), (2, 1), (0, 3))):
        put(im, x + ox, y + oy, s[3 + k % 3])
    ball(im, x, y, 2, 2, "straw", lo=0.4, hi=0.9)


def _torso(im, cx, top, bottom, half0, ramp, sq):
    """Stuffed coat: wider at the hem, a belt of rope, straw at the hem."""
    for y in range(top, bottom + 1):
        t = (y - top) / max(1, bottom - top)
        half = half0 + t * 3 + (sq * 0.5 if y > top + 3 else 0)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - cx) / max(1.0, half)
            fold = 0.07 * math.sin((x - cx) * 0.9 + y * 0.15)
            v = 0.72 - u * 0.28 - t * 0.15 + fold
            put(im, x, y, P.ramp_d(ramp, v, x, y))
    # rope belt
    by = top + int((bottom - top) * 0.62)
    for x in range(int(cx - half0 - 2), int(cx + half0 + 3)):
        put(im, x, by, R("straw")[2 + (x % 2)])
    # straw poking out at the hem
    s = R("straw")
    for k in range(-int(half0 + 3), int(half0 + 4), 2):
        put(im, cx + k, bottom + 1, s[3 + (k % 3 == 0)])
        put(im, cx + k, bottom + 2, s[4])
    # patch
    rect(im, cx + 2, top + 4, cx + 4, top + 6, R("straw")[2])
    put(im, cx + 3, top + 5, R("straw")[4])


def _sack_head(im, cx, cy, r=8, eyes="#2a1a12", glow_eyes=None):
    ball(im, cx, cy, r, r * 0.95, "straw", lo=0.45, hi=1.0)
    # stitched face: button eyes and a sewn smile
    for ex in (cx - 3, cx + 3):
        rect(im, ex - 1, cy - 1, ex, cy, eyes)
        if glow_eyes:
            put(im, ex - 1, cy - 1, glow_eyes)
        else:
            put(im, ex - 1, cy - 1, "#6a4a3a")
    line(im, cx - 4, cy + 4, cx + 4, cy + 4, "#6a3a20")
    for k in range(-4, 5, 2):
        put(im, cx + k, cy + 5, "#6a3a20")
        put(im, cx + k, cy + 3, "#6a3a20")
    # cheek blush
    put(im, cx - 5, cy + 2, "#e09070")
    put(im, cx + 5, cy + 2, "#e09070")


def _rot(px, py, ang):
    a = math.radians(ang)
    return px * math.cos(a) - py * math.sin(a), px * math.sin(a) + py * math.cos(a)


def _shaft(im, x, y, ang, back, front, c0, c1):
    """A pole through hand (x, y): angle 0 = pointing up."""
    a = math.radians(ang)
    dx, dy = math.sin(a), -math.cos(a)
    n = back + front
    for k in range(-back, front + 1):
        px, py = x + dx * k, y + dy * k
        put(im, px, py, c0)
        put(im, px + (1 if abs(dy) > 0.5 else 0), py + (1 if abs(dy) <= 0.5 else 0), c1)
    return x + dx * front, y + dy * front, dx, dy


def _whoosh(im, cx, cy, r, a0, a1, color="#fff8e0"):
    """Motion smear of a swing: a thin crescent from angle a0 to a1."""
    n = 24
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        for t in range(3 if 4 < i < n - 4 else 1):
            put(im, cx + math.sin(a) * (r - t), cy - math.cos(a) * (r - t), color, 200 - t * 50)


def _pose(f):
    return POSES[f]


# ---------------------------------------------------------------- straw guard
def straw_guard(f):
    """Tank: pitchfork and a round plank shield, blue patched coat, straw hat."""
    p = _pose(f)
    im = new(W, H)
    _shadow(im)
    _stake(im, 46)
    _mound(im)
    b, lean = p["bob"], p["lean"]
    top = 36 + b
    sx = CX + lean
    # left arm holds the shield (behind it), right arm the pitchfork
    lx, ly = _limb(im, sx - 7, top + 2, -p["l"], 9, 2.2, "cloth_blue", 0.2, 0.6)
    rx, ry = _limb(im, sx + 7, top + 2, p["r"], 9, 2.2, "cloth_blue", 0.3, 0.75)
    _torso(im, sx, top, 56 + b // 2, 6, "cloth_blue", p["sq"])
    # pitchfork: angle follows the arm, tines up
    fang = {"idle_0": 8, "idle_1": 6, "atk_0": -20, "atk_1": 28, "atk_2": 14}[f]
    w = R("wood")
    ex, ey, dx, dy = _shaft(im, rx, ry, fang, 8, 24, w[3], w[2])
    # tines
    for k in (-3, 0, 3):
        ox, oy = _rot(k, 0, fang)
        bx, by = ex + ox, ey + oy
        for t in range(6):
            put(im, bx + dx * t, by + dy * t, "#c8ccd8" if t < 4 else "#e8ecf4")
    ox, oy = _rot(3.5, 0, fang)
    line(im, ex - ox, ey - oy, ex + ox, ey + oy, "#8a8ea0")
    _cuff(im, rx, ry)
    _sack_head(im, sx, top - 9 + (1 if p["sq"] > 0 else 0))
    # straw hat with a red band
    hy = top - 16 + (1 if p["sq"] > 0 else 0)
    for x in range(sx - 13, sx + 14):
        put(im, x, hy, "#f0d47a")
        put(im, x, hy + 1, "#b8903e")
    for yy in range(hy - 7, hy):
        for x in range(sx - 6, sx + 7):
            put(im, x, yy, "#f0d47a" if x < sx + 2 else "#d0aa50")
    rect(im, sx - 6, hy - 2, sx + 6, hy - 1, "#c84a3e")
    # shield in front of the left side
    shx, shy = lx - 1, ly - 2
    ball(im, shx, shy, 7, 8, "wood", lo=0.3, hi=0.95)
    rect(im, shx - 7, shy - 1, shx + 7, shy, R("wood")[2])
    ball(im, shx, shy, 2, 2, "gold", lo=0.4, hi=1.0)
    _cuff(im, lx + 3, ly + 2)
    im = outline(im)
    if f == "atk_1":
        glow(im, ex + dx * 5, ey + dy * 5, 7, "#fff4c0", 0.55)
    return im


# ---------------------------------------------------------------- crow archer
def crow_archer(f):
    """Ranged: green hooded scarecrow with a longbow, a crow on the shoulder."""
    p = dict(_pose(f))
    # the archer keeps both arms raised toward the sky while shooting
    p["l"] = {"idle_0": 150, "idle_1": 148, "atk_0": 165, "atk_1": 160, "atk_2": 155}[f]
    p["r"] = {"idle_0": 50, "idle_1": 46, "atk_0": 125, "atk_1": 95, "atk_2": 70}[f]
    im = new(W, H)
    _shadow(im)
    _stake(im, 46)
    _mound(im)
    b, lean = p["bob"], p["lean"]
    top = 36 + b
    sx = CX + lean
    lx, ly = _limb(im, sx - 7, top + 2, -p["l"], 10, 2.1, "leaf", 0.25, 0.6)
    rx, ry = _limb(im, sx + 7, top + 2, p["r"], 8, 2.1, "leaf", 0.3, 0.7)
    _torso(im, sx, top, 56 + b // 2, 6, "leaf", p["sq"])
    # quiver on the back (peeks over the right shoulder)
    rect(im, sx + 6, top - 6, sx + 8, top + 4, R("wood")[3])
    for k in range(3):
        put(im, sx + 6 + k, top - 7, "#e8e0d0")
        put(im, sx + 6 + k, top - 8, "#d24c4e")
    # bow held up-left: a curved limb through the left hand
    pull = {"idle_0": 0, "idle_1": 0, "atk_0": 4, "atk_1": 0, "atk_2": 1}[f]
    w = R("wood")
    pts = []
    for k in range(-13, 14):
        bend = (169 - k * k) / 30.0
        x = lx - 2 - bend
        y = ly + k * 0.95 - 2
        pts.append((x, y))
        put(im, x, y, w[4])
        put(im, x + 1, y, w[3])
    (ax, ay), (bx2, by2) = pts[0], pts[-1]
    mx = lx + 2 + pull * 1.2
    line(im, ax, ay, mx, ly - 2, "#f0ece0")
    line(im, mx, ly - 2, bx2, by2, "#f0ece0")
    if f in ("idle_0", "idle_1", "atk_0"):
        line(im, mx, ly - 2, lx - 9, ly - 2, "#e8d8b0")  # nocked arrow
        put(im, lx - 10, ly - 2, "#c8ccd8")
        put(im, lx - 10, ly - 3, "#c8ccd8")
    _cuff(im, lx, ly)
    _cuff(im, rx, ry)
    hy = top - 9 + (1 if p["sq"] > 0 else 0)
    _sack_head(im, sx, hy)
    # hood over the head
    for y in range(hy - 10, hy - 1):
        for x in range(sx - 10, sx + 11):
            if ((x + 0.5 - sx) / 10) ** 2 + ((y + 0.5 - hy + 1) / 9.5) ** 2 <= 1:
                put(im, x, y, P.ramp_d("leaf", 0.55 - (x - sx) / 40 - (hy - y) / 60, x, y))
    for y in range(hy - 2, hy + 7):
        put(im, sx - 9, y, R("leaf")[2])
        put(im, sx + 9, y, R("leaf")[1])
    # crow on the right shoulder, beak open on the strike
    cx, cy = sx + 11, top - 2
    ball(im, cx, cy, 4, 3, "cape", lo=0.05, hi=0.4)
    ball(im, cx + 2, cy - 3, 2.4, 2.2, "cape", lo=0.05, hi=0.45)
    put(im, cx + 4, cy - 3, "#f0a02e")
    if f == "atk_1":
        put(im, cx + 5, cy - 4, "#f0a02e")
    put(im, cx + 2, cy - 4, "#ffe080")
    im = outline(im)
    if f == "atk_1":
        glow(im, lx - 6, ly - 4, 6, "#fff4c0", 0.5)
    return im


# ---------------------------------------------------------------- pumpkin brute
def pumpkin_brute(f):
    """Melee splash: big jack-o'-lantern head, red coat, heavy log club."""
    p = dict(_pose(f))
    p["r"] = {"idle_0": 60, "idle_1": 55, "atk_0": 165, "atk_1": 95, "atk_2": 62}[f]
    im = new(W, H)
    _shadow(im)
    _stake(im, 48)
    _mound(im)
    b, lean = p["bob"], p["lean"]
    top = 38 + b
    sx = CX + lean
    lx, ly = _limb(im, sx - 9, top + 2, -p["l"], 9, 2.6, "cloth_red", 0.2, 0.6)
    rx, ry = _limb(im, sx + 9, top + 2, p["r"], 9, 2.6, "cloth_red", 0.3, 0.75)
    _torso(im, sx, top, 58 + b // 2, 8, "cloth_red", p["sq"])
    # club: a log with iron bands
    cang = {"idle_0": 25, "idle_1": 22, "atk_0": -15, "atk_1": 80, "atk_2": 50}[f]
    w = R("wood")
    ex, ey, dx, dy = _shaft(im, rx, ry, cang, 3, 12, w[3], w[2])
    for k in range(8):
        cxk, cyk = ex + dx * k, ey + dy * k
        ball(im, cxk, cyk, 3.4 + k * 0.12, 3.4 + k * 0.12, "wood", lo=0.3, hi=0.9)
    for k in (2, 6):
        ox, oy = _rot(4, 0, cang)
        bx, by = ex + dx * k, ey + dy * k
        line(im, bx - ox, by - oy, bx + ox, by + oy, "#8a8ea0")
    _cuff(im, rx, ry)
    _cuff(im, lx, ly)
    hy = top - 10 + (1 if p["sq"] > 0 else 0)
    ball(im, sx, hy, 12, 9.5, "pumpkin", lo=0.15, hi=0.95)
    for k in (-7, 7):  # ribs, kept off the face
        for y in range(hy - 8, hy + 9):
            if abs(y - hy) > 6 and ((k / 12) ** 2 + ((y - hy) / 9.5) ** 2) < 0.92:
                put(im, sx + k, y, R("pumpkin")[2])
    lit = "#ffe070" if f != "atk_1" else "#fff8c8"
    rim = "#5a1a0a"
    for ex2 in (sx - 5, sx + 4):  # carved triangle eyes, glowing inside
        for yy in range(3):
            for xx in range(-yy, yy + 1):
                put(im, ex2 + xx, hy - 4 + yy, lit)
            put(im, ex2 - yy - 1, hy - 4 + yy, rim)
            put(im, ex2 + yy + 1, hy - 4 + yy, rim)
        rect(im, ex2 - 3, hy - 1, ex2 + 3, hy - 1, rim)
    rect(im, sx - 6, hy + 2, sx + 6, hy + 4, lit)  # grin with two teeth
    rect(im, sx - 6, hy + 5, sx + 6, hy + 5, rim)
    rect(im, sx - 7, hy + 2, sx - 7, hy + 4, rim)
    rect(im, sx + 7, hy + 2, sx + 7, hy + 4, rim)
    put(im, sx - 2, hy + 2, rim)
    put(im, sx + 2, hy + 4, rim)
    rect(im, sx - 1, hy - 13, sx + 1, hy - 9, R("leaf")[2])
    put(im, sx + 2, hy - 12, R("leaf")[4])
    put(im, sx + 3, hy - 13, R("leaf")[4])
    im = outline(im)
    glow(im, sx, hy, 8, "#ffb040", 0.25 if f != "atk_1" else 0.45)
    if f == "atk_1":
        glow(im, ex + dx * 7, ey + dy * 7, 9, "#fff0c0", 0.6)
    return im


# ---------------------------------------------------------------- frost sentinel
def frost_sentinel(f):
    """Support caster: cabbage-leaf helm, frost cloak, ice-crystal staff."""
    p = dict(_pose(f))
    p["l"] = {"idle_0": 150, "idle_1": 152, "atk_0": 170, "atk_1": 160, "atk_2": 155}[f]
    im = new(W, H)
    _shadow(im)
    _stake(im, 46)
    _mound(im)
    b, lean = p["bob"], p["lean"]
    top = 36 + b
    sx = CX + lean
    lx, ly = _limb(im, sx - 7, top + 2, -p["l"], 8, 2.2, "frost", 0.25, 0.6)
    rx, ry = _limb(im, sx + 7, top + 2, p["r"], 9, 2.2, "frost", 0.3, 0.75)
    # long cloak
    _torso(im, sx, top, 59 + b // 2, 7, "frost", p["sq"])
    # staff in the raised left hand with a crystal on top
    w = R("wood")
    sang = {"idle_0": -6, "idle_1": -4, "atk_0": -14, "atk_1": 4, "atk_2": -2}[f]
    ex, ey, dx, dy = _shaft(im, lx, ly, sang, 16, 6, w[4], w[3])
    cxs, cys = ex + dx * 3, ey + dy * 3
    for y in range(-6, 7):
        half = 3 - abs(y) * 0.5
        for x in range(int(-half), int(half) + 1):
            put(im, cxs + x, cys + y, P.ramp_d("frost", 0.95 - (x + 3) / 10 - (y + 6) / 30, cxs + x, cys + y))
    _cuff(im, lx, ly)
    _cuff(im, rx, ry)
    hy = top - 9 + (1 if p["sq"] > 0 else 0)
    _sack_head(im, sx, hy, glow_eyes="#b0f0ff")
    # cabbage-leaf helm
    for y in range(hy - 11, hy - 1):
        for x in range(sx - 10, sx + 11):
            if ((x + 0.5 - sx) / 10) ** 2 + ((y + 0.5 - hy + 1) / 10) ** 2 <= 1:
                v = 0.85 - (x - sx) / 35 - (hy - y) / 50 + 0.08 * math.sin((x - sx) * 1.3)
                put(im, x, y, P.ramp_d("frost", v, x, y))
    for k in (-6, 0, 6):
        line(im, sx + k, hy - 10, sx + k * 0.7, hy - 3, "#e4f4fc")
    im = outline(im)
    glow(im, cxs, cys, 9 if f == "atk_1" else 6, "#b0f0ff", 0.6 if f == "atk_1" else 0.35)
    return im


HEROES = {
    "straw_guard": straw_guard,
    "crow_archer": crow_archer,
    "pumpkin_brute": pumpkin_brute,
    "frost_sentinel": frost_sentinel,
}


def sprites():
    out = {}
    for hid, fn in HEROES.items():
        for fr in FRAMES:
            out["def_hero_%s_%s" % (hid, fr)] = fn(fr)
    return out
