"""Isometric buildings and props for the game. Every sprite stands on the
front (bottom) corner of its footprint, which is the bottom-centre of the
canvas; one tile along x or y is 24 px across and 12 px down (48 x 24 px
diamonds). Sun from the upper left: the front-left wall is lit, the
front-right wall is in shade."""
import math
import random

from .draw import ball, line, new, outline, put, rect
from . import palette as P

STEP = 0.5


class Iso:
    """Canvas with an iso projection. a runs from the front corner to the
    right corner (tiles along -y), b to the left corner (tiles along -x)."""

    def __init__(self, w_tiles, h_tiles, height):
        self.A, self.B = h_tiles * 24, w_tiles * 24
        half = max(self.A, self.B) + 6
        self.w = half * 2
        self.h = int(height + (self.A + self.B) / 2 + 8)
        self.ox, self.oy = half, self.h - 1
        self.im = new(self.w, self.h)

    def p(self, a, b, z):
        return self.ox + a - b, self.oy - (a + b) / 2 - z

    def put(self, a, b, z, c):
        x, y = self.p(a, b, z)
        put(self.im, x, y, c)


def _face(iso, axis, fixed, s0, s1, z0, z1, color):
    """Fill a wall: axis 'a' spans a with b=fixed (right wall), 'b' spans b
    with a=fixed (left wall). color(s, z) -> colour or None."""
    s = s0
    while s <= s1:
        z = z0
        while z <= z1:
            c = color(s, z)
            if c:
                if axis == "a":
                    iso.put(s, fixed, z, c)
                else:
                    iso.put(fixed, s, z, c)
            z += STEP
        s += STEP


def house(iso, a0, a1, b0, b1, H, R, wall="wall", roof="roof", base=6, timber=True, windows=(), door=None,
          chimney=None, ridge_along_a=True, roof_lo=0.4, roof_hi=0.62, gold_trim=False, stories=1):
    """A walled building with a gable roof inside the footprint box."""
    Rm = P.RAMPS
    wd, st = Rm["wood"], Rm["stone"]
    A, B = a1 - a0, b1 - b0

    def gable_z(s, span):
        return H + R * (1 - abs(2 * s / span - 1))

    def roof_pass(front):
        # ridge along a: slopes face +b (back-left) and -b (front-right)
        if ridge_along_a:
            lo, hi = (b0 + B / 2, b1 + 3) if not front else (b0 - 3, b0 + B / 2)
            b = lo
            while b <= hi:
                a = a0 - 3
                while a <= a1 + 3:
                    z = H + R * (1 - abs(2 * (b - b0) / B - 1))
                    row = int(abs(b - (b0 + B / 2)) / 3)
                    t = (roof_hi if front else roof_lo) + (0.07 if row % 2 else 0) - (a - a0) / max(1, A) * 0.08
                    if int(a + row * 3) % 7 == 0:
                        t -= 0.12
                    if gold_trim and abs(b - (b0 - 3)) < 1:
                        c = Rm["gold"][4]
                    else:
                        c = P.ramp_d(roof, t, int(a), int(b))
                    iso.put(a, b, z, c)
                    a += STEP
                b += STEP
        else:
            lo, hi = (a0 + A / 2, a1 + 3) if not front else (a0 - 3, a0 + A / 2)
            a = lo
            while a <= hi:
                b = b0 - 3
                while b <= b1 + 3:
                    z = H + R * (1 - abs(2 * (a - a0) / A - 1))
                    row = int(abs(a - (a0 + A / 2)) / 3)
                    t = (roof_hi + 0.08 if front else roof_lo) + (0.07 if row % 2 else 0)
                    if int(b + row * 3) % 7 == 0:
                        t -= 0.12
                    iso.put(a, b, z, P.ramp_d(roof, t, int(a), int(b)))
                    b += STEP
                a += STEP

    roof_pass(False)

    def wall_col(lit):
        def f(s, z):
            if z < base:
                edge = int(z) % 3 == 2 or int(s + (z // 3) * 3) % 7 == 0
                return st[1] if edge else P.ramp_d("stone", 0.62 if lit else 0.4, int(s), int(z))
            t = (0.78 if lit else 0.5) + P.fbm(s, z, 4 if lit else 5, 8, 2) * 0.06
            c = P.ramp_d(wall, t, int(s), int(z))
            if timber:
                if abs(z - H) < 1.2 or abs(z - base) < 0.8 or (stories > 1 and abs(z - H / 2) < 0.8):
                    c = wd[4] if lit else wd[3]
            return c
        return f

    # left wall (lit), with its gable when the ridge runs along a
    def left(s, z):
        zt = gable_z(s - b0, B) if ridge_along_a else H
        if z > zt:
            return None
        if z > H:
            return P.ramp_d("wood", 0.62 + (0.1 if int(s) % 4 else 0), int(s), int(z))
        c = wall_col(True)(s, z)
        if timber and (s - b0 < 1.5 or b1 - s < 1.5) and z >= base:
            c = wd[4]
        return c

    def right(s, z):
        zt = gable_z(s - a0, A) if not ridge_along_a else H
        if z > zt:
            return None
        if z > H:
            return P.ramp_d("wood", 0.45 + (0.08 if int(s) % 4 else 0), int(s), int(z))
        c = wall_col(False)(s, z)
        if timber and (s - a0 < 1.5 or a1 - s < 1.5) and z >= base:
            c = wd[3]
        return c

    _face(iso, "b", a0, b0, b1, 0, H + R, left)
    _face(iso, "a", b0, a0, a1, 0, H + R, right)

    def rect_on(face, s0, s1, z0, z1, col):
        fixed = b0 if face == "r" else a0
        _face(iso, "a" if face == "r" else "b", fixed, s0, s1, z0, z1,
              (lambda s, z: col(s - s0, z - z0)) if callable(col) else (lambda s, z: col))

    for (face, s, z) in windows:
        rect_on(face, s - 1, s + 11, z - 1, z + 11, wd[1])
        rect_on(face, s, s + 10, z, z + 10, lambda u, v: P.ramp_d("glow", 0.3 + (10 - v) / 10 * 0.45, int(u * 2), int(v * 2)))
        rect_on(face, s + 5, s + 5.5, z, z + 10, wd[2])
        rect_on(face, s, s + 10, z + 5, z + 5.5, wd[2])
        rect_on(face, s - 1, s + 11, z - 2.5, z - 1, wd[3])
        for k in range(4):
            rect_on(face, s + k * 3, s + k * 3 + 1, z - 1, z, ("#e87a84", "#f2d050", "#f4f0e6", "#b88ae0")[k])
    if door:
        face, s, w, h = door
        rect_on(face, s - 1, s + w + 1, 0, h + 1, wd[1])
        rect_on(face, s, s + w, 0, h, lambda u, v: P.ramp_d("wood", 0.4 + (0.12 if int(u * 2) % 3 else 0), 0, 0))
        rect_on(face, s + w - 2, s + w - 1.5, h * 0.45, h * 0.5, Rm["gold"][4])

    roof_pass(True)
    if ridge_along_a:
        a = a0 - 3
        while a <= a1 + 3:
            iso.put(a, b0 + B / 2, H + R + 1, Rm[roof][-1] if int(a) % 4 else Rm[roof][-3])
            a += STEP
    if chimney:
        ca, cb, ch = chimney
        for z in range(int(H + R * 0.4), int(H + R + ch)):
            for k in range(7):
                iso.put(ca + k * 0.7, cb, z, st[4] if k < 3 else st[2])
                iso.put(ca, cb + k * 0.7, z, st[5] if k < 3 else st[3])
        for k in range(8):
            iso.put(ca + k * 0.7, cb, H + R + ch, st[5])


def _finish(iso):
    outline(iso.im)
    return iso.im


def footprint_shadow(w_tiles, h_tiles, width):
    """Soft shadow under a building: the footprint diamond, pushed a little
    to the lower right (sun upper left). Its bottom row is the front corner."""
    A, B = h_tiles * 24, w_tiles * 24
    hgt = int((A + B) / 2) + 4
    im = new(width, hgt)
    ox, oy = width // 2, hgt - 1
    for y in range(hgt):
        for x in range(width):
            # inverse projection, then test the shifted footprint
            dx, dy = x + 0.5 - ox - 4, oy - (y + 0.5) + 1
            a = dy + dx / 2
            b = dy - dx / 2
            if -2 <= a <= A + 2 and -2 <= b <= B + 2:
                put(im, x, y, "#1c3418", 70)
    return im


# ------------------------------------------------------------------ manor
MANOR = [
    # A/B inset, wall height, roof rise, roof ramp, wall ramp, extras
    dict(inset=14, H=20, R=14, roof="straw", wall="wall", win=1, chimney=False),
    dict(inset=10, H=24, R=16, roof="straw", wall="wall", win=2, chimney=True),
    dict(inset=8, H=28, R=18, roof="roof", wall="wall", win=2, chimney=True),
    dict(inset=6, H=30, R=20, roof="roof", wall="wall", win=3, chimney=True),
    dict(inset=5, H=40, R=20, roof="slate", wall="wall", win=3, chimney=True, stories=2),
    dict(inset=4, H=44, R=22, roof="royal", wall="wall_white", win=3, chimney=True, stories=2, gold=True),
]


def manor(tier):
    m = MANOR[tier]
    iso = Iso(3, 3, m["H"] + m["R"] + 26)
    i = m["inset"]
    a0, a1, b0, b1 = i, iso.A - i, i, iso.B - i
    A = a1 - a0
    wins = []
    if m["win"] >= 1:
        wins.append(("l", b0 + (b1 - b0) / 2 - 5, 10))
    if m["win"] >= 2:
        wins.append(("r", a0 + 6, 10))
    if m["win"] >= 3:
        wins.append(("r", a1 - 17, 10))
    if m.get("stories") == 2:
        wins += [("r", a0 + 6, 28), ("r", a1 - 17, 28), ("l", b0 + (b1 - b0) / 2 - 5, 28)]
    house(iso, a0, a1, b0, b1, m["H"], m["R"], wall=m["wall"], roof=m["roof"], windows=wins,
          door=("r", a0 + A / 2 - 5, 10, 17), chimney=(a0 + A * 0.7, b0 + (b1 - b0) * 0.62, 10) if m["chimney"] else None,
          stories=m.get("stories", 1), gold_trim=m.get("gold", False))
    return _finish(iso)


# ------------------------------------------------------------------ buildings
def workshop(level):
    H = (20, 24, 28)[level]
    iso = Iso(2, 2, H + 30)
    house(iso, 6, iso.A - 6, 6, iso.B - 6, H, 14, wall="plank", roof=("straw", "roof", "slate")[level], timber=False,
          windows=[("l", 14, 9)], door=("r", 10, 18, 16), ridge_along_a=False)
    # sawhorse and logs by the door
    rnd = random.Random(level)
    for k in range(3 + level):
        x, y = iso.p(iso.A - 4, -4 - k * 3, 0)
        ball(iso.im, x, y - 2, 3, 2.2, "wood", lo=0.3, hi=0.95)
    return _finish(iso)


def forge(level):
    H = (18, 22, 26)[level]
    iso = Iso(2, 2, H + 44)
    house(iso, 6, iso.A - 6, 6, iso.B - 6, H, 10, wall="stone_wall", roof="slate", timber=False, base=0,
          windows=[("l", 14, 7)], door=("r", 12, 16, 14), chimney=(iso.A * 0.6, iso.B * 0.6, 14 + level * 4))
    # glow from the open door
    x, y = iso.p(20, 6, 6)
    from .draw import glow
    glow(iso.im, x, y, 10, "#ff9628", 0.5)
    return _finish(iso)


def well(level):
    iso = Iso(1, 1, 44)
    im = iso.im
    cx, cy = iso.p(12, 12, 0)
    st = P.RAMPS["stone"]
    for z in range(0, 9):  # round stone ring
        for k in range(64):
            ang = k / 64 * math.tau
            x, y = cx + math.cos(ang) * 10, cy + math.sin(ang) * 5 - z
            if math.sin(ang) > -0.1 or z == 8:
                t = 0.4 + (0.25 if math.cos(ang) < 0 else 0) + (0.1 if (k + z // 3) % 5 == 0 else 0)
                put(im, x, y, P.ramp_d("stone", t, int(x), int(y)))
    for x in range(int(cx - 8), int(cx + 9)):
        for y in range(int(cy - 12), int(cy - 6)):
            if ((x + 0.5 - cx) / 8) ** 2 + ((y + 0.5 - cy + 9) / 3.5) ** 2 < 1:
                put(im, x, y, P.RAMPS["water"][1 + level % 2])
    wd = P.RAMPS["wood"]
    for dx in (-9, 9):
        rect(im, cx + dx - 1, cy - 30, cx + dx, cy - 4, wd[3])
    rect(im, cx - 10, cy - 26, cx + 10, cy - 25, wd[2])
    for y in range(int(cy - 38), int(cy - 29)):
        half = (y - (cy - 38)) * 1.6
        for x in range(int(cx - half), int(cx + half) + 1):
            put(im, x, y, P.ramp_d(("straw", "roof", "slate")[level], 0.55 - (x - cx) / 30, x, y))
    rect(im, cx - 1, cy - 22, cx + 1, cy - 18, wd[4])
    return _finish(iso)


def order_board(level):
    iso = Iso(1, 1, 40)
    im = iso.im
    cx, cy = iso.p(12, 12, 0)
    wd = P.RAMPS["wood"]
    for dx in (-10, 9):
        rect(im, cx + dx, cy - 30, cx + dx + 1, cy, wd[3])
    for y in range(int(cy - 30), int(cy - 12)):
        for x in range(int(cx - 12), int(cx + 13)):
            put(im, x, y, P.ramp_d("wood", 0.7 - (x - cx + 12) / 25 * 0.3, x, y))
    rnd = random.Random(level)
    for k in range(2 + level):
        x0 = cx - 10 + k * 7 + rnd.randint(0, 1)
        y0 = cy - 28 + rnd.randint(0, 3)
        rect(im, x0, y0, x0 + 5, y0 + 7, "#f0e0c8")
        put(im, x0 + 2, y0, "#d24c4e")
        line(im, x0 + 1, y0 + 3, x0 + 4, y0 + 3, "#a08a70")
        line(im, x0 + 1, y0 + 5, x0 + 3, y0 + 5, "#a08a70")
    rect(im, cx - 13, cy - 32, cx + 13, cy - 30, wd[4])
    return _finish(iso)


def watchtower(level):
    Ht = (54, 62, 70)[level]
    iso = Iso(1, 1, Ht + 28)
    wd = P.RAMPS["wood"]
    a0, a1, b0, b1 = 4, 20, 4, 20
    for (a, b) in ((a0, b0), (a1, b0), (a0, b1)):  # three visible legs
        for z in range(0, Ht):
            iso.put(a, b, z, wd[4] if a == a0 else wd[2])
            iso.put(a + 0.7, b, z, wd[3])
    for z in range(8, Ht - 4, 12):  # cross braces
        for k in range(17):
            iso.put(a0, b0 + k, z + k * 0.6, wd[3])
            iso.put(a0 + k, b0, z + k * 0.6, wd[2])
    # platform with a rail
    for b in range(b0 - 4, b1 + 4):
        for a in range(a0 - 4, a1 + 4):
            iso.put(a, b, Ht, P.ramp_d("wood", 0.55, a, b))
    for z in range(Ht, Ht + 8):
        for k in range(a0 - 4, a1 + 4):
            if z == Ht + 7 or k % 5 == 0:
                iso.put(k, b0 - 4, z, wd[3])
        for k in range(b0 - 4, b1 + 4):
            if z == Ht + 7 or k % 5 == 0:
                iso.put(a0 - 4, k, z, wd[4])
    # pointed roof
    for z in range(0, 18):
        r = (18 - z) / 18 * 16
        for k in range(int(-r * 2), int(r * 2) + 1):
            s = k / 2
            iso.put(12 + s, 12 - r, Ht + 14 + z, P.ramp_d(("straw", "roof", "slate")[level], 0.45, int(s), z))
            iso.put(12 - r, 12 + s, Ht + 14 + z, P.ramp_d(("straw", "roof", "slate")[level], 0.7, int(s), z))
    # banner
    x, y = iso.p(12, 12, Ht + 32)
    rect(iso.im, x, y - 10, x, y, wd[2])
    for k in range(6):
        line(iso.im, x + 1, y - 10 + k // 2, x + 7 - k // 2, y - 8 + k // 3, P.RAMPS["cloth_red"][3])
    return _finish(iso)


def site():
    iso = Iso(1, 1, 24)
    wd = P.RAMPS["wood"]
    pts = [(2, 2), (22, 2), (2, 22), (22, 22)]
    for (a, b) in pts:
        for z in range(0, 9):
            iso.put(a, b, z, wd[4] if z < 8 else wd[5])
    for (p0, p1) in ((pts[0], pts[1]), (pts[0], pts[2]), (pts[1], pts[3]), (pts[2], pts[3])):
        for k in range(21):
            t = k / 20
            iso.put(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, 6 - math.sin(t * math.pi) * 1.5, "#e8d8a8")
    x, y = iso.p(12, 12, 0)
    rect(iso.im, x - 1, y - 16, x, y - 2, wd[3])
    rect(iso.im, x - 6, y - 20, x + 6, y - 13, wd[4])
    rect(iso.im, x - 5, y - 19, x + 5, y - 14, "#f0e0c8")
    line(iso.im, x - 3, y - 17, x + 3, y - 17, "#a08a70")
    return _finish(iso)


# ------------------------------------------------------------------ windmill
def windmill():
    """Stone tower on a 2 x 3 footprint; the sails (separate sprite) turn on
    a hub 80 px above the front corner."""
    iso = Iso(2, 3, 110)
    A, B = iso.A, iso.B
    ca, cb = A / 2, B / 2
    st = P.RAMPS["stone"]
    r0, r1, Ht = 20, 15, 74
    # round tower: draw rings from bottom to top, front half only + top cap
    for z in range(0, Ht):
        r = r0 + (r1 - r0) * z / Ht
        for k in range(96):
            ang = k / 96 * math.tau
            a, b = ca + math.cos(ang) * r, cb + math.sin(ang) * r
            x, y = iso.p(a, b, z)
            lit = math.cos(ang - math.pi * 0.75)  # facing the upper-left sun
            t = 0.45 + lit * 0.22 + (0.08 if (z // 4 + k // 6) % 2 else 0)
            if z % 4 == 3:
                t -= 0.12
            put(iso.im, x, y, P.ramp_d("wall_white", t, int(x), int(y)))
    for z in range(0, 26):  # conical cap
        r = r1 + 3 - z * (r1 + 3) / 26
        for k in range(96):
            ang = k / 96 * math.tau
            a, b = ca + math.cos(ang) * r, cb + math.sin(ang) * r
            x, y = iso.p(a, b, Ht + z)
            lit = math.cos(ang - math.pi * 0.75)
            put(iso.im, x, y, P.ramp_d("roof", 0.45 + lit * 0.2, int(x), int(y)))
    # door and window toward the front
    x, y = iso.p(ca - r0 * 0.7, cb - r0 * 0.7, 0)
    rect(iso.im, x - 4, y - 16, x + 4, y, P.RAMPS["wood"][1])
    rect(iso.im, x - 3, y - 15, x + 3, y, P.RAMPS["wood"][3])
    x, y = iso.p(ca - r0 * 0.6, cb - r0 * 0.6, 40)
    rect(iso.im, x - 3, y - 4, x + 3, y + 4, P.RAMPS["wood"][1])
    rect(iso.im, x - 2, y - 3, x + 2, y + 3, P.RAMPS["glow"][2])
    return _finish(iso)


def sails():
    """Four cloth sails, 80 x 80 px, hub in the middle (front view)."""
    im = new(80, 80)
    wd = P.RAMPS["wood"]
    for k in range(4):
        ang = k * math.pi / 2 + 0.3
        ca, sa = math.cos(ang), math.sin(ang)
        for d in range(4, 38):
            x, y = 40 + ca * d, 40 + sa * d
            put(im, x, y, wd[2])
            put(im, x + 1, y, wd[3])
            if d > 10:
                for w in range(1, 9):
                    px, py = x - sa * w, y + ca * w
                    put(im, px, py, "#efe4cc" if (d + w) % 6 else "#c8b89c")
    ball(im, 40, 40, 4, 4, "wood", lo=0.3, hi=0.95)
    return outline(im)


# ------------------------------------------------------------------ pond, stones, fence
def pond(frame):
    iso = Iso(3, 2, 6)
    A, B = iso.A, iso.B
    cx, cy = iso.p(A / 2, B / 2, 0)
    rx, ry = (A + B) / 2 * 0.78, (A + B) / 4 * 0.78
    from .ground import draw_pond
    draw_pond(iso.im, cx, cy, rx, ry, seed=5 + frame)
    return iso.im


def stones():
    iso = Iso(1, 1, 4)
    for (a, b, r) in ((8, 10, 4.5), (16, 14, 4), (12, 4, 3.5)):
        x, y = iso.p(a, b, 0)
        ball(iso.im, x, y - 1, r * 1.3, r * 0.6, "stone", lo=0.35, hi=0.95)
    return _finish(iso)


def fence_piece():
    """A fence through the middle of a tile, along +x (screen "\\")."""
    from .iso import fence_edge
    f = fence_edge(True)  # lower end at (w-2, h-1)
    im = new(48, f.height + 8)
    # lower end of the rail goes 6 px above the tile's front corner, 12 px right of it
    im.alpha_composite(f, (36 - (f.width - 2), im.height - 1 - 6 - (f.height - 1)))
    return im


def scarecrow_small():
    """The hd scarecrow with a shorter pole so it is about one tile wide
    and two tall."""
    from . import objects as O
    sc = O.scarecrow()
    bb = sc.getbbox()
    top = sc.crop((0, 0, sc.width, 66))           # hat, head, cape, top of the pole
    foot = sc.crop((0, bb[3] - 8, sc.width, bb[3]))  # pole foot with its outline
    out = new(sc.width, 74)
    out.alpha_composite(top, (0, 0))
    out.alpha_composite(foot, (0, 66))
    return out


def sprites():
    """All isometric object sprites by game name (shipped @2x)."""
    P.RAMPS.setdefault("slate", ["#1e2230", "#2c3242", "#3c4456", "#4e586c", "#647086", "#7e8ca2", "#9aa8bc"])
    P.RAMPS.setdefault("royal", ["#1a1e3a", "#262c54", "#343e72", "#46548e", "#5c6ea8", "#7a8cc2", "#a0b0da"])
    P.RAMPS.setdefault("plank", ["#3a2418", "#523222", "#6c4430", "#86583c", "#a0704a", "#b8885a"])
    P.RAMPS.setdefault("stone_wall", ["#2e2a34", "#46424c", "#5e5a64", "#78727c", "#928c96", "#aca6ae"])
    P.RAMPS.setdefault("wall_white", ["#6e6458", "#8e8474", "#aea290", "#c8bea8", "#ddd4c0", "#ece6d6"])
    s = {}
    for t in range(6):
        s["prop_manor_%d" % t] = manor(t)
        s["shadow_manor_%d" % t] = footprint_shadow(3, 3, s["prop_manor_%d" % t].width)
    for bid, fn, (w, h) in (("workshop", workshop, (2, 2)), ("forge", forge, (2, 2)), ("well", well, (1, 1)),
                            ("order_board", order_board, (1, 1)), ("watchtower", watchtower, (1, 1))):
        for lv in range(3):
            im = fn(lv)
            s["bld_%s_%d" % (bid, lv)] = im
            s["shadow_bld_%s_%d" % (bid, lv)] = footprint_shadow(w, h, im.width)
    s["bld_site"] = site()
    s["prop_windmill"] = windmill()
    s["shadow_windmill"] = footprint_shadow(2, 3, s["prop_windmill"].width)
    s["prop_windmill_sails"] = sails()
    s["prop_pond_0"] = pond(0)
    s["prop_pond_1"] = pond(1)
    s["prop_stones"] = stones()
    s["prop_fence"] = fence_piece()
    s["prop_scarecrow"] = scarecrow_small()
    return s
