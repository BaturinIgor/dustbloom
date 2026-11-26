"""Isometric (2.5D) test frame of the same farm in the daytime palette.
Tiles are 40 x 20 px diamonds; buildings are iso boxes with lit left walls
(sun from the upper left). Run from art/: python3 -m hd.frame_iso"""
import math
import os
import random

from PIL import Image, ImageChops, ImageFilter

TW, TH = 40, 20

# calmer daylight: less saturated greens, earthier roof and soil
SOFT = {
    "grass": ["#22382a", "#2c4a31", "#3a5e38", "#4b7240", "#5f8548", "#7a9a56", "#9cb46a"],
    "dust": ["#5a4434", "#725640", "#8a6a4c", "#a07e5a", "#b49268", "#c6a67a", "#d6ba90"],
    "roof": ["#2e1c1e", "#4a2624", "#66342c", "#844436", "#a05842", "#b87054", "#cc8e6e"],
    "leaf": ["#1c3424", "#264a2c", "#335e34", "#47743c", "#5e8a46", "#7ca054", "#a0b86a"],
    "wall": ["#4a3428", "#6e5038", "#927050", "#b49068", "#cfae82", "#e2c89e"],
}


def main():
    from . import game as G
    G.setup()
    from . import palette as P
    P.RAMPS.update(SOFT)
    from . import frame as F
    from . import objects as O
    from . import props as Pr
    from .draw import ball, cast_shadow, glow, mix, new, outline, put, rect, sparkle
    from .ground import draw_dust, draw_grass, draw_pond, grass_mask, turf_edges
    from .palette import RAMPS as R, dither, fbm, hash01, noise2, ramp_d
    F.COLORS.update({
        "#26163a": "#4a2c1c", "#34204c": "#5a3622", "#4a2f66": "#74482c", "#1a0f28": "#2e1a10",
        "#140818": "#1e100a", "#200f30": "#3a2214", "#e8d8f0": "#f0e0c8",
    })
    W, H = F.W, F.H
    im = new(W, H)
    m = grass_mask(W, H, [(14, 92, 246, 430)], edge=14)
    draw_dust(im, m)
    draw_grass(im, m)
    turf_edges(im, m)

    OX, OY = 132, 236  # screen position of field grid corner (0, 0)

    def iso(i, j):
        return OX + (i - j) * TW / 2, OY + (i + j) * TH / 2

    # ---- worn path from the door to the field (iso stepping stones)
    for k in range(6):
        x, y = 92 + k * 6, 196 + k * 4
        ball(im, x, y, 4.5, 2.2, "stone", lo=0.3, hi=0.95)

    # ---- field: trodden soil diamond, then a raised mound per bed
    cols, rows = 5, 4

    def in_diamond(px, py, i0, j0, i1, j1, pad=0.0):
        u = ((px - OX) / (TW / 2) + (py - OY) / (TH / 2)) / 2
        v = ((py - OY) / (TH / 2) - (px - OX) / (TW / 2)) / 2
        return i0 - pad <= u <= i1 + pad and j0 - pad <= v <= j1 + pad, u, v

    for y in range(OY - 20, OY + (cols + rows) * TH // 2 + 20):
        for x in range(OX - rows * TW // 2 - 20, OX + cols * TW // 2 + 20):
            ok, u, v = in_diamond(x + 0.5, y + 0.5, 0, 0, cols, rows, 0.12)
            if ok:
                put(im, x, y, ramp_d("soil", 0.16 + fbm(x, y, 7, 6, 2) * 0.1, x, y))
    wdr = R["wood"]
    band = set()
    for y in range(OY - 24, OY + (cols + rows) * TH // 2 + 24):
        for x in range(OX - rows * TW // 2 - 24, OX + cols * TW // 2 + 24):
            ok_out, u, v = in_diamond(x + 0.5, y + 0.5, 0, 0, cols, rows, 0.26)
            ok_in, _, _ = in_diamond(x + 0.5, y + 0.5, 0, 0, cols, rows, 0.12)
            if ok_out and not ok_in:
                band.add((x, y))
    for (x, y) in band:  # plank tops, lit on the back edges
        back = (x, y + 1) in band or (x, y + 2) in band
        put(im, x, y - 3, wdr[5] if not back and (x + y) % 9 else wdr[4])
    for (x, y) in band:  # front faces under the front edges
        if (x, y + 1) not in band:
            ok_in, u, v = in_diamond(x + 0.5, y - 4.5, 0, 0, cols, rows, 0.12)
            if not ok_in:
                for k in range(-2, 2):
                    put(im, x, y + k, wdr[2] if k < 0 else wdr[1])
    for r in range(rows):
        for c in range(cols):
            for y in range(OY - 4, OY + (cols + rows) * TH // 2 + 4):
                for x in range(OX - rows * TW // 2, OX + cols * TW // 2):
                    ok, u, v = in_diamond(x + 0.5, y + 0.5, c + 0.1, r + 0.1, c + 0.9, r + 0.9)
                    if not ok:
                        continue
                    fu, fv = u - c, v - r
                    # mound height: front faces (high u or v) are darker sides
                    if fu > 0.8 or fv > 0.8:
                        t = 0.22 if fu > fv else 0.32
                    elif fu < 0.18 or fv < 0.18:
                        t = 0.8
                    else:
                        t = 0.6 - fu * 0.1
                        f = int(fv * 9 + noise2(x, y, 7, 3) * 0.8) % 3
                        t = 0.72 if f == 0 else 0.62 if f == 1 else 0.4  # furrows along u
                        if hash01(x, y, 7) < 0.07:
                            t += 0.16
                    put(im, x, y - 2, ramp_d("soil", t, x, y))

    # ---- iso box building
    def iso_house(cx, by, A, B, Hh, Rr):
        """Front corner of the footprint at (cx, by). Right wall runs along
        +a (screen (+1, -0.5)), left wall along +b (screen (-1, -0.5))."""
        sp = new(A + B + 16, int(Hh + Rr + (A + B) / 2 + 20))
        ox, oy = B + 8, sp.height - 2

        def P(a, b, z):
            return ox + a - b, oy - (a + b) / 2 - z

        wd, st = R["wood"], R["stone"]
        step = 0.5
        # back roof slope
        def roof(b0, b1, front):
            b = b0
            while b <= b1:
                a = -4
                while a <= A + 4:
                    z = Hh + Rr * (1 - abs(2 * b / B - 1))
                    x, y = P(a, b, z)
                    row = int((b if front else B - b) / 3.2)
                    t = (0.62 if front else 0.4) + (0.08 if row % 2 else 0) - a / A * 0.1
                    if int(a + row * 3) % 7 == 0:
                        t -= 0.14
                    put(sp, x, y, ramp_d("roof", t, int(x), int(y)))
                    a += step
                b += step
        roof(B / 2, B + 4, False)
        # left wall (lit) with gable
        b = 0
        while b <= B:
            zt = Hh + Rr * (1 - abs(2 * b / B - 1))
            z = 0
            while z <= zt:
                x, y = P(0, b, z)
                if z < 6:
                    c = st[1] if (int(z) % 3 == 2 or int(b + (z // 3) * 3) % 7 == 0) else ramp_d("stone", 0.62, x, y)
                elif z > Hh:
                    c = ramp_d("wood", 0.62 + (0.1 if int(b) % 4 else 0), x, y)
                else:
                    c = ramp_d("wall", 0.78 + fbm(x, y, 4, 8, 2) * 0.06, x, y)
                    if int(b) in (0, 1) or abs(b - B) < 1.5 or abs(z - Hh) < 1.5 or abs(z - 6) < 1:
                        c = wd[4]
                put(sp, x, y, c)
                z += step
            b += step
        # right wall (shade)
        a = 0
        while a <= A:
            z = 0
            while z <= Hh:
                x, y = P(a, 0, z)
                if z < 6:
                    c = st[1] if (int(z) % 3 == 2 or int(a + (z // 3) * 3) % 7 == 0) else ramp_d("stone", 0.38, x, y)
                else:
                    c = ramp_d("wall", 0.5 + fbm(x, y, 5, 8, 2) * 0.05, x, y)
                    if int(a) in (0, 1) or abs(a - A) < 1.5 or abs(z - Hh) < 1.5 or abs(z - 6) < 1 or abs(a - A / 2) < 1:
                        c = wd[3]
                put(sp, x, y, c)
                z += step
            a += step

        # windows and door drawn in wall coordinates
        def wall_rect(face, s0, s1, z0, z1, col):
            s = s0
            while s <= s1:
                z = z0
                while z <= z1:
                    x, y = P(s, 0, z) if face == "r" else P(0, s, z)
                    put(sp, x, y, col(s - s0, z - z0) if callable(col) else col)
                    z += step
                s += step
        for (s0, face) in ((6, "r"), (A - 18, "r"), (B / 2 - 6, "l")):
            wall_rect(face, s0 - 1, s0 + 13, 11, 25, wd[1])
            wall_rect(face, s0, s0 + 12, 12, 24,
                      lambda u, v: ramp_d("glow", 0.35 + v / 12 * 0.5, int(u * 2), int(v * 2)))
            wall_rect(face, s0 + 6, s0 + 6.5, 12, 24, wd[2])
            wall_rect(face, s0, s0 + 12, 17.5, 18, wd[2])
            wall_rect(face, s0 - 1, s0 + 13, 9, 10.5, wd[3])
            for k in range(5):
                wall_rect(face, s0 + k * 3, s0 + k * 3 + 1, 10.5, 12,
                          ("#ff7a8a", "#ffd34a", "#ffffff", "#c88aff", "#ff9a4a")[k])
        dx = A / 2 - 6
        wall_rect("r", dx + 3, dx + 13, 0, 18, wd[1])
        wall_rect("r", dx + 4, dx + 12, 0, 17, lambda u, v: ramp_d("wood", 0.45 + (0.1 if int(u * 2) % 3 else 0), 0, 0))
        wall_rect("r", dx + 10, dx + 10.5, 8, 9, R["gold"][4])
        roof(-4, B / 2, True)
        # ridge cap and chimney
        a = -4
        while a <= A + 4:
            x, y = P(a, B / 2, Hh + Rr + 1)
            put(sp, x, y, R["roof"][6] if int(a) % 4 else R["roof"][4])
            a += step
        for zc in range(int(Hh + Rr - 6), int(Hh + Rr + 12)):
            for k in range(6):
                x, y = P(A * 0.72 + k * 0.8, B * 0.62, zc)
                put(sp, x, y, st[4] if k < 3 else st[2])
                put(sp, x + 0.5, y, st[4] if k < 3 else st[2])
        outline(sp)
        return sp, cx - ox, by - oy

    objs = []

    def add(sp, x, base, shadow=True, ao=None):
        objs.append((base, sp, x, base - sp.height, shadow, ao if ao is not None else sp.width * 0.6))

    house, hx, hy = iso_house(78, 206, 60, 44, 30, 20)
    objs.append((206, house, hx, hy, True, 0))

    # iso fence along the back-right of the yard
    def iso_fence(n):
        sp = new(n * 10 + 6, n * 5 + 20)
        wd = R["wood"]
        for k in range(n + 1):
            x, y = 2 + k * 10, sp.height - 2 - k * 5
            rect(sp, x, y - 15, x + 2, y, wd[3])
            rect(sp, x, y - 15, x, y, wd[4])
            put(sp, x + 1, y - 16, wd[4])
            if k < n:
                for z in (5, 11):
                    for d in range(10):
                        put(sp, x + 1 + d, y - z - d / 2, wd[4])
                        put(sp, x + 1 + d, y - z - d / 2 + 1, wd[2])
        return outline(sp)
    fz = iso_fence(7)
    add(fz, 142, 214, shadow=False, ao=0)

    add(O.blossom_tree(), 140, 172, ao=28)
    add(O.scarecrow(), 194, 386, ao=14)
    add(O.farmer(1), 16, 312, ao=14)
    for (x, y, f, fl) in ((150, 398, 0, False), (172, 410, 1, True), (132, 418, 1, False)):
        add(O.hen(f, fl), x, y, ao=10)
    add(Pr.barrel(), 22, 236, ao=12)
    add(Pr.crate(), 34, 244, ao=16)
    add(Pr.mailbox(), 132, 238, ao=8)
    add(Pr.hay_bale(), 6, 276, ao=18)
    add(Pr.log_pile(), 200, 238, ao=20)
    add(Pr.dog(0), 112, 412, ao=16)
    add(Pr.bush(30, 20, 3), 2, 430, ao=22)
    add(Pr.bush(24, 16, 4, berries="#5a8aff"), 222, 430, ao=18)
    add(Pr.bush(26, 18, 2, berries="#ff4a6a"), 14, 180, ao=20)
    add(O.rock(), 10, 96, ao=14)
    add(O.dead_tree(4), 214, 520, ao=12)

    draw_pond(im, 62, 390, 40, 20)

    crops = [["w"] * 5, ["p", "p", "p2", "p", "p"], ["t", "t", "s", "t", "t"], ["s", "s", "s", "s", None]]
    for r, row in enumerate(crops):
        for c, k in enumerate(row):
            if k is None:
                continue
            sp = {"w": O.wheat(3, seed=c + r * 7), "p": O.ember_pumpkin(3), "p2": O.ember_pumpkin(2),
                  "t": O.moon_turnip(2), "s": O.sprout()}[k]
            bb = sp.getbbox()
            sp = sp.crop((0, 0, sp.width, bb[3]))
            x, y = iso(c + 0.5, r + 0.5)
            objs.append((y + 3, sp, int(x - sp.width / 2), int(y + 3 - sp.height), False, 0))

    for base, sp, x, y, sh, ao in objs:
        if sh:
            im.alpha_composite(cast_shadow(sp, alpha=70), (x, y))
    for base, sp, x, y, sh, ao in objs:
        if ao:
            F.contact_shadow(im, x + sp.width / 2, base, ao, 5 if ao > 40 else 3)
    for i, (base, sp, x, y, sh, ao) in enumerate(sorted(objs, key=lambda o: o[0])):
        im.alpha_composite(sp, (x, y))

    # smoke, butterflies, sparkles
    rnd = random.Random(3)
    for i in range(12):
        cx, cy = 128 + i * 1.4 + math.sin(i) * 2, 104 - i * 4
        r = 2 + i * 0.35
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if math.hypot(x - cx, y - cy) <= r and rnd.random() < 0.9 - i * 0.05:
                    mix(im, x, y, "#ffffff" if x < cx else "#d8dce8", 0.55 - i * 0.035)
    from life_art import life_sprites
    lf = life_sprites()
    for (x, y, f) in ((110, 130, 0), (170, 290, 1), (30, 350, 0)):
        im.alpha_composite(lf["life_butterfly_%d" % f], (x, y))
    for (x, y) in iso(0.5, 0.5), iso(2.5, 0.5), iso(1.5, 1.5):
        sparkle(im, int(x), int(y) - 22, 3)
    # selected empty bed: gold iso brackets
    sx, sy = iso(4.5, 3.5)
    for k in range(6):
        for (dx, dy) in ((-TW / 2 + 2 + k * 2, -k), (-TW / 2 + 2 + k * 2, k), (TW / 2 - 2 - k * 2, -k),
                         (TW / 2 - 2 - k * 2, k)):
            put(im, sx + dx, sy - 2 + dy, "#ffce50")

    screen = im.resize((W * F.S, H * F.S), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * F.K, 844 * F.K))
    canvas.alpha_composite(screen, (0, (844 * F.K - screen.height) // 2))
    base = canvas.convert("RGB")
    from PIL import ImageEnhance
    base = ImageEnhance.Color(base).enhance(0.9)
    base = ImageEnhance.Brightness(base).enhance(0.96)
    canvas = base.convert("RGBA")
    F.hud_parts(canvas)
    out = canvas.convert("RGB")
    out.save(os.path.join(F.ART, "target-iso.png"))
    out.save("/mnt/project-files/stage1/target-frame-iso.png")
    print("ok")


if __name__ == "__main__":
    main()
