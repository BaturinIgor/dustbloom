"""Target frame v3: closer camera (2 pt per art pixel), clean large shapes
instead of noisy dither, foreground framing for depth, light pools and
rays. Run from art/: python3 -m hd.frame3"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from . import objects as O
from .draw import ball, cast_shadow, glow, mix, new, outline, put, sparkle
from .frame import ART, K, hud_parts
from .ground import draw_pond, turf_edges
from .palette import RAMPS, dither, fbm, hash01, noise2, ramp_d

R = RAMPS
W, H = 195, 422   # art px; 2 pt per px on a 390 x 844 pt screen
S = 4             # screen px per art px at @2x


def mask_from(cores, edge=10, seed=3):
    m = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            d = 1e9
            for (x0, y0, x1, y1) in cores:
                d = min(d, math.hypot(max(x0 - x, 0, x - x1), max(y0 - y, 0, y - y1)))
            m[y][x] = d + fbm(x, y, seed, 26, 2) * 9 < edge
    return m


def band(v, cuts, x, y, soft=0.025):
    """Posterise v into bands; dither only in a thin seam at each cut."""
    i = 0
    for c in cuts:
        if v > c + soft:
            i += 1
        elif v > c - soft:
            i += 1 if dither(x, y, (v - c + soft) / (2 * soft)) else 0
    return i


def clean_grass(im, m):
    g = R["grass"]
    for y in range(H):
        for x in range(W):
            if not m[y][x]:
                continue
            v = fbm(x, y, 2, 34, 2) + (1 - x / W) * 0.18 + (1 - y / H) * 0.1
            i = band(v, (-0.05, 0.12, 0.3), x, y)
            put(im, x, y, (g[1], g[2], g[3], g[4])[i])
    rnd = random.Random(5)
    for _ in range(150):  # tuft clusters: a few clean blades
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        if not m[cy][cx]:
            continue
        for k in range(rnd.randint(2, 4)):
            x, y = cx + rnd.randint(-3, 3), cy + rnd.randint(-1, 1)
            if not (0 <= y < H and 0 <= x < W and m[y][x]):
                continue
            put(im, x, y + 1, g[2])
            put(im, x, y, g[4])
            put(im, x - 1, y - 1, g[4])
            put(im, x + 1, y - 1, g[5])
    for _ in range(26):  # flower patches
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        col = rnd.choice(("#ffd6dc", "#fff4a0", "#ffffff", "#c2b0e0"))
        for k in range(rnd.randint(3, 6)):
            x, y = cx + rnd.randint(-5, 5), cy + rnd.randint(-3, 3)
            if 1 <= y < H - 1 and 1 <= x < W - 1 and m[y][x] and m[y + 1][x]:
                put(im, x, y + 1, g[2])
                put(im, x, y, col)
                put(im, x - 1, y, col)
                put(im, x + 1, y, col)
                put(im, x, y - 1, col)
                put(im, x, y, "#ffce50")


def clean_dust(im, m):
    d = R["dust"]
    for y in range(H):
        for x in range(W):
            if m[y][x]:
                continue
            v = fbm(x, y, 1, 30, 2) + (1 - y / H) * 0.05
            i = band(v, (-0.15, 0.05, 0.22), x, y)
            c = (d[2], d[3], d[4], d[5])[i]
            r = abs(noise2(x, y, 9, 18))
            if r < 0.025:
                c = d[1]
            put(im, x, y, c)


def soil_beds(im, x0, y0, cols, rows, tile=32):
    s = R["soil"]
    x1, y1 = x0 + cols * tile, y0 + rows * tile
    for y in range(y0 - 3, y1 + 3):
        for x in range(x0 - 3, x1 + 3):
            if (x < x0 - 1 or x > x1) and (y < y0 - 1 or y > y1):
                continue
            put(im, x, y, s[2])
    for r in range(rows):
        for c in range(cols):
            l, t = x0 + c * tile + 2, y0 + r * tile + 2
            rr, b = l + tile - 5, t + tile - 5
            for y in range(t, b + 1):
                for x in range(l, rr + 1):
                    if (x in (l, rr)) and (y in (t, b)):
                        continue
                    if y >= b - 2:
                        col = s[1]
                    elif y == t:
                        col = s[5]
                    else:
                        fy = (y - t - 1) % 9
                        col = s[4] if fy == 0 else s[1] if fy == 7 else s[3]
                        if x >= rr - 1:
                            col = s[2]
                    put(im, x, y, col)


def light_pool(im, cx, cy, rx, ry, color="#ffce50", a=0.35):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d < 1:
                t = (1 - d)
                if dither(x, y, min(1, t * 1.6)):
                    mix(im, x, y, color, a * t + 0.08)


def foreground_branch():
    """Dark blossoming branch hanging into the top-left corner."""
    im = new(110, 70)
    rnd = random.Random(8)
    for i in range(70):
        x, y = -4 + i * 1.2, 8 + math.sin(i * 0.08) * 6 + i * 0.25
        for k in range(4 - i // 25):
            put(im, x, y + k, R["wood"][1])
    blobs = [(10, 18, 16, 12), (34, 22, 14, 10), (58, 30, 13, 9), (80, 38, 11, 8), (22, 34, 12, 8)]
    for (bx, by, rx, ry) in blobs:
        ball(im, bx, by, rx, ry, "leaf", lo=0.0, hi=0.45)
    for _ in range(90):
        bx, by, rx, ry = rnd.choice(blobs)
        a = rnd.random() * 6.283
        r = rnd.random() ** 0.5 * 0.9
        x, y = bx + math.cos(a) * rx * r, by + math.sin(a) * ry * r
        put(im, x, y, R["blossom"][2])
        put(im, x + 1, y, R["blossom"][1])
    outline(im)
    return im


def foreground_bush():
    im = new(90, 60)
    blobs = [(20, 40, 20, 16), (48, 34, 20, 18), (72, 44, 18, 14), (40, 52, 22, 10)]
    for (bx, by, rx, ry) in blobs:
        ball(im, bx, by, rx, ry, "leaf", lo=0.0, hi=0.55)
    rnd = random.Random(4)
    for _ in range(60):
        bx, by, rx, ry = rnd.choice(blobs)
        a = rnd.random() * 6.283
        x, y = bx + math.cos(a) * rx * 0.7, by + math.sin(a) * ry * 0.7
        put(im, x, y, R["leaf"][4])
        put(im, x + 1, y + 1, R["leaf"][2])
    for (x, y) in ((30, 30), (55, 24), (70, 36), (20, 44)):
        put(im, x, y, "#ff9fb0")
        put(im, x + 1, y, "#ffd6dc")
    outline(im)
    return im


def world():
    im = new(W, H)
    cores = [(6, 26, 190, 348), (14, 348, 120, 372)]
    m = mask_from(cores)
    clean_dust(im, m)
    clean_grass(im, m)
    turf_edges(im, m)
    # path from the door to the field
    for i in range(60):
        t = i / 59
        cx, cy = 60 + t * 20, 142 + t * 30
        for y in range(int(cy - 3), int(cy + 4)):
            for x in range(int(cx - 6), int(cx + 7)):
                if ((x - cx) / 6.5) ** 2 + ((y - cy) / 3.5) ** 2 < 1:
                    put(im, x, y, R["soil"][4] if hash01(x, y, 2) > 0.15 else R["soil"][5])
    draw_pond(im, 46, 330, 38, 16)
    soil_beds(im, 22, 176, 4, 3)

    objs = []

    def add(sp, x, base, shadow=True, ao=None):
        objs.append((base, sp, x, base - sp.height, shadow, ao if ao is not None else sp.width * 0.7))

    add(O.house(), 2, 140, ao=96)
    add(O.fence(52), 0, 160, ao=0)
    add(O.fence(100), 96, 160, ao=0)
    add(O.scarecrow(), 146, 286, ao=14)
    add(O.farmer(1), 98, 318, ao=14)
    for (x, y, f, fl) in ((128, 336, 0, False), (150, 346, 1, True), (112, 352, 0, True)):
        add(O.hen(f, fl), x, y, ao=10)
    crops = [["w", "w", "w", "w"], ["p", "p", "p2", "p"], ["t", "s", "t", None]]
    for r, row in enumerate(crops):
        for c, k in enumerate(row):
            if k is None:
                continue
            sp = {"w": O.wheat(3, seed=c + 3), "p": O.ember_pumpkin(3), "p2": O.ember_pumpkin(2),
                  "t": O.moon_turnip(2), "s": O.sprout()}[k]
            add(sp, 22 + c * 32, 176 + (r + 1) * 32 - 2, shadow=k in ("w", "p"), ao=0)

    for base, sp, x, y, sh, ao in objs:
        if sh:
            im.alpha_composite(cast_shadow(sp, alpha=70), (x, y))
    for base, sp, x, y, sh, ao in objs:
        if ao:
            for yy in range(base - 4, base + 2):
                for xx in range(int(x + sp.width / 2 - ao / 2), int(x + sp.width / 2 + ao / 2)):
                    d = ((xx - x - sp.width / 2) / (ao / 2)) ** 2 + ((yy - base + 1) / 3) ** 2
                    if d < 1:
                        mix(im, xx, yy, "#1e101e", 0.45 * (1 - d) + 0.1)
    for base, sp, x, y, sh, ao in sorted(objs, key=lambda o: o[0]):
        im.alpha_composite(sp, (x, y))
    # warm light pools from the windows and the lantern
    light_pool(im, 30, 150, 18, 7)
    light_pool(im, 86, 150, 18, 7)
    light_pool(im, 70, 146, 9, 5, a=0.45)
    # smoke
    rnd = random.Random(3)
    for i in range(12):
        cx, cy = 84 + i * 1.6 + math.sin(i) * 2, 32 - i * 4
        r = 2 + i * 0.35
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if math.hypot(x - cx, y - cy) <= r:
                    mix(im, x, y, "#c2b0e0" if x < cx else "#967cbe", 0.45 - i * 0.03)
    for (x, y) in ((32, 180), (96, 182), (64, 210), (128, 186)):
        sparkle(im, x, y, 3)
    for _ in range(14):
        x, y = rnd.randrange(8, 186), rnd.randrange(40, 360)
        glow(im, x, y, 4, "#fff4a0", 0.7)
        put(im, x, y, "#ffffff")
    # foreground framing: darker, so it reads as closer to the camera
    bush = foreground_bush()
    im.alpha_composite(bush, (W - 70, 318))
    for (x, y) in ((40, 110), (24, 200), (110, 250), (160, 120), (70, 300)):  # falling petals
        put(im, x, y, R["blossom"][3])
        put(im, x + 1, y, R["blossom"][2])
    return im


def grade(img):
    w, h = img.size
    base = img.convert("RGB")
    bright = base.point(lambda v: max(0, v - 215) * 2)
    base = ImageChops.add(base, bright.filter(ImageFilter.GaussianBlur(6 * K)).point(lambda v: int(v * 0.6)))
    small = Image.new("RGB", (w // 8, h // 8))
    sp = small.load()
    for y in range(small.height):
        for x in range(small.width):
            u, v = x / small.width, y / small.height
            sun = max(0.0, 1 - math.hypot(u + 0.1, v * 0.8 + 0.1) * 1.0) ** 2
            ang = math.atan2(v + 0.2, u + 0.2)
            ray = max(0.0, math.sin(ang * 17 + 0.6)) ** 8 * max(0.0, 1 - math.hypot(u, v) * 0.85) * 0.45
            a = sun * 0.55 + ray
            sp[x, y] = (int(110 * a), int(60 * a), int(22 * a))
    base = ImageChops.add(base, small.resize((w, h), Image.BILINEAR))
    tint = Image.new("L", (w // 8, h // 8))
    tp = tint.load()
    for y in range(tint.height):
        for x in range(tint.width):
            u, v = x / tint.width, y / tint.height
            d = math.hypot((u - 0.45) / 0.62, (v - 0.42) / 0.62)
            tp[x, y] = int(255 * min(1.0, max(0.0, (d - 0.45) / 0.8)) * 0.75)
    base = Image.composite(Image.new("RGB", (w, h), (30, 14, 46)), base, tint.resize((w, h), Image.BILINEAR))
    return base.convert("RGBA")


def main():
    wimg = world()
    # push the farm down so the roof clears the top bar
    shifted = new(W, H)
    shifted.alpha_composite(wimg.crop((0, 0, W, 14)), (0, 0))
    shifted.alpha_composite(wimg.crop((0, 0, W, H - 14)), (0, 14))
    screen = shifted.resize((W * S, H * S), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * K, 844 * K))
    canvas.alpha_composite(screen, (0, 0))
    canvas = grade(canvas)
    hud_parts(canvas, tray=False, gain=(80, 362))
    out = canvas.convert("RGB")
    out.save(os.path.join(ART, "target-v3.png"))
    out.save("/mnt/project-files/stage1/target-frame-v3.png")
    print("ok")


if __name__ == "__main__":
    main()
