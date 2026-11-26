"""Ground drawn per pixel: living grass that rises like turf over the mauve
wasteland, cracked dust with pebbles, a pond that mirrors the sunset sky,
and a raised field with a plank frame."""
import math
import random

from .draw import ball, mix, put, rect
from .palette import RAMPS, dither, fbm, hash01, noise2, ramp_d


def grass_mask(w, h, cores, edge=12, seed=3):
    """True where grass grows: within `edge` px of a core rect, with a
    noisy, organic border."""
    m = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            d = 1e9
            for (x0, y0, x1, y1) in cores:
                dx = max(x0 - x, 0, x - x1)
                dy = max(y0 - y, 0, y - y1)
                d = min(d, math.hypot(dx, dy))
            n = fbm(x, y, seed, 22, 3) * 11 + noise2(x, y, seed + 5, 4) * 2
            m[y][x] = d + n < edge
    return m


def draw_dust(im, mask, seed=1):
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if mask[y][x]:
                continue
            n = fbm(x, y, seed, 26, 3)
            t = 0.42 + n * 0.22 + (1 - y / h) * 0.05 - x / w * 0.06
            c = ramp_d("dust", t, x, y, 0.8)
            # dry cracks along noise ridges
            r = abs(noise2(x, y, seed + 9, 14) + noise2(x, y, seed + 11, 5) * 0.25)
            if r < 0.035:
                c = RAMPS["dust"][1]
            elif r < 0.07 and dither(x, y, 0.5):
                c = RAMPS["dust"][2]
            put(im, x, y, c)
    rnd = random.Random(seed)
    for _ in range(w * h // 900):  # pebbles
        x, y = rnd.randrange(w), rnd.randrange(h)
        if mask[y][x]:
            continue
        r = rnd.choice((1.2, 1.6, 2.2))
        put(im, x + 1, y + r + 0.5, RAMPS["dust"][0])
        ball(im, x, y, r + 0.4, r, "dust", lo=0.35, hi=1.0)


def draw_grass(im, mask, seed=2):
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            n = fbm(x, y, seed, 20, 3)
            light = (1 - x / w) * 0.08 + (1 - y / h) * 0.06  # sun top-left
            t = 0.32 + n * 0.26 + light
            put(im, x, y, ramp_d("grass", t, x, y, 0.9))
    rnd = random.Random(seed)
    g = RAMPS["grass"]
    for _ in range(w * h // 22):  # tufts: light blades with a dark root
        x, y = rnd.randrange(w), rnd.randrange(2, h)
        if not mask[y][x]:
            continue
        hi = rnd.random() < 0.55
        put(im, x, y + 1, g[1] if hi else g[2])
        put(im, x, y, g[4] if hi else g[3])
        if rnd.random() < 0.6:
            put(im, x - 1, y - 1, g[4] if hi else g[3])
        if rnd.random() < 0.6:
            put(im, x + 1, y - 1, g[4] if hi else g[3])
        if hi and rnd.random() < 0.3:
            put(im, x, y - 1, g[6])
    for _ in range(w * h // 700):  # flowers
        x, y = rnd.randrange(2, w - 2), rnd.randrange(2, h - 2)
        if not (mask[y][x] and mask[y + 1][x]):
            continue
        petal = rnd.choice(("#ffd6dc", "#ff9fb0", "#fff4a0", "#ffffff", "#c2b0e0"))
        put(im, x, y + 1, g[1])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(im, x + dx, y + dy, petal)
        put(im, x, y, "#ffce50")


def turf_edges(im, mask):
    """Grass is a raised turf: soil side under its lower edge, a lit lip on
    its upper edge, and a soft shadow on the dust below."""
    w, h = im.size
    s = RAMPS["soil"]
    g = RAMPS["grass"]
    d = RAMPS["dust"]
    for y in range(h):
        for x in range(w):
            if mask[y][x]:
                below = [y + k < h and not mask[y + k][x] for k in (1, 2, 3)]
                if below[0]:
                    put(im, x, y, s[2] if dither(x, y, 0.5) else s[3])
                elif below[1]:
                    put(im, x, y, s[3])
                elif below[2]:
                    put(im, x, y, g[1])
                elif y > 0 and not mask[y - 1][x]:
                    put(im, x, y, g[6] if dither(x, y, 0.6) else g[5])
                elif (x > 0 and not mask[y][x - 1]) or (x < w - 1 and not mask[y][x + 1]):
                    put(im, x, y, g[2])
            else:
                if y >= 1 and mask[y - 1][x]:
                    put(im, x, y, d[0])
                elif y >= 2 and mask[y - 2][x] and dither(x, y, 0.5):
                    put(im, x, y, d[1])


def draw_pond(im, cx, cy, rx, ry, seed=5):
    """Pond mirroring the sunset: sky gradient upside down, ripples, lily
    pads, stones on the rim and reeds."""
    sky = RAMPS["sky"]
    w = RAMPS["water"]
    for y in range(int(cy - ry) - 3, int(cy + ry) + 4):
        for x in range(int(cx - rx) - 3, int(cx + rx) + 4):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            wob = noise2(x, y, seed, 6) * 0.06
            d = dx * dx + dy * dy + wob
            if d > 1.22:
                continue
            if d > 1.0:  # muddy bank
                put(im, x, y, RAMPS["soil"][2] if dy < 0 else RAMPS["soil"][3])
                continue
            # reflection: far side (top) mirrors the bright horizon
            t = (dy + 1) / 2  # 0 top .. 1 bottom
            sk = 1 - t
            c = ramp_d("sky", 0.25 + sk * 0.75, x, y)
            if t > 0.55:
                c = ramp_d("water", 0.85 - (t - 0.55) * 1.6, x, y)
            if d > 0.86:
                c = w[1] if dy < 0 else w[2]
            # ripples
            if abs(math.sin((y * 1.7 + noise2(x, y, seed + 3, 9) * 6))) < 0.12 and d < 0.8 and hash01(x // 3, y, seed) < 0.5:
                c = "#ffde96" if t < 0.5 else w[4]
            put(im, x, y, c)
    rnd = random.Random(seed)
    for (px, py, r) in ((cx - rx * 0.45, cy + ry * 0.25, 4.5), (cx + rx * 0.35, cy + ry * 0.45, 3.5),
                        (cx + rx * 0.05, cy + ry * 0.6, 3)):
        ball(im, px, py, r + 1, r * 0.7, "leaf", lo=0.3, hi=0.95)
        put(im, px + 1, py, RAMPS["leaf"][1])
        put(im, px + 2, py, RAMPS["leaf"][1])
    put(im, cx - rx * 0.45 - 1, cy + ry * 0.25 - 2, "#ff9fb0")
    put(im, cx - rx * 0.45, cy + ry * 0.25 - 2, "#ffd6dc")
    put(im, cx - rx * 0.45 - 1, cy + ry * 0.25 - 3, "#ffd6dc")
    for a in range(0, 360, 14):  # rim stones on the near side
        ang = math.radians(a)
        if math.sin(ang) < -0.2:
            continue
        x = cx + math.cos(ang) * (rx + 2)
        y = cy + math.sin(ang) * (ry + 2)
        r = 1.6 + rnd.random() * 1.6
        ball(im, x, y, r + 0.6, r, "stone", lo=0.15, hi=0.9)
    for i in range(7):  # reeds on the left bank
        x = cx - rx - 1 + i * 2 + rnd.randint(-1, 1)
        y0 = cy - 2 + rnd.randint(-2, 3)
        hgt = rnd.randint(7, 12)
        for k in range(hgt):
            put(im, x + (1 if k > hgt * 0.7 else 0), y0 - k, RAMPS["leaf"][3 if k < hgt / 2 else 4])
        if i % 2 == 0:
            rect(im, x, y0 - hgt - 3, x + 1, y0 - hgt, RAMPS["wood"][3])
            put(im, x, y0 - hgt - 3, RAMPS["wood"][5])


def draw_field(im, x0, y0, cols, rows, tile=32, seed=7):
    """Trodden soil yard with a raised, rounded mound for every bed."""
    s = RAMPS["soil"]
    x1, y1 = x0 + cols * tile - 1, y0 + rows * tile - 1
    for y in range(y0 - 4, y1 + 5):
        for x in range(x0 - 4, x1 + 5):
            corner = (x < x0 - 1 or x > x1 + 1) and (y < y0 - 1 or y > y1 + 1)
            if corner:
                continue
            n = fbm(x, y, seed, 6, 2)
            put(im, x, y, ramp_d("soil", 0.3 + n * 0.12, x, y))
    for r in range(rows):
        for c in range(cols):
            bx, by = x0 + c * tile, y0 + r * tile
            l, t, rr, b = bx + 2, by + 2, bx + tile - 3, by + tile - 3
            for y in range(t, b + 1):
                for x in range(l, rr + 1):
                    if (x in (l, rr) and y in (t, t + 1, b, b - 1)) or (x in (l + 1, rr - 1) and y in (t, b)):
                        continue
                    if y >= b - 3:  # front face of the mound
                        tt = 0.2 if y == b else 0.3
                    elif y <= t + 1:  # lit top lip
                        tt = 0.82
                    else:
                        tt = 0.6 - (x - l) / (rr - l) * 0.12
                        fy = int(y - t - 2 + noise2(x, y, seed, 3) * 1.6) % 8
                        if fy == 0:
                            tt = 0.74 if dither(x, y, 0.6) else 0.62  # ridge catches the light
                        elif fy == 1:
                            tt = 0.7
                        elif fy in (6, 7):
                            tt = 0.38  # furrow
                        if hash01(x, y, seed) < 0.08:
                            tt += 0.18
                        elif hash01(x, y, seed + 1) < 0.08:
                            tt -= 0.15
                    if x == l or x == rr:
                        tt -= 0.12
                    put(im, x, y, ramp_d("soil", tt, x, y))
            # mound casts a little shadow on the yard
            for x in range(l + 1, rr + 2):
                put(im, x, b + 1, s[0] if dither(x, b, 0.5) else s[1])
