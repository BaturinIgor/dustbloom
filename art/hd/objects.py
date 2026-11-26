"""High-detail sprites in the app icon's style: manor house, blossoming tree,
pumpkin-head scarecrow, farmer, hens, well, fence, crops, wasteland props.
Light comes from the low sun at the top-left; shadows are purple."""
import math
import random

from .draw import ball, glow, line, mix, new, outline, put, rect, sparkle
from .palette import RAMPS, dither, fbm, hash01, noise2, ramp_d

R = RAMPS


# ------------------------------------------------------------------ house
def house():
    W, H = 108, 108
    im = new(W, H)
    fx0, fx1, fy0, fy1 = 12, 95, 56, 98  # facade
    # foundation stones
    rnd = random.Random(2)
    for y in range(fy1 - 6, fy1 + 4):
        for x in range(fx0 - 2, fx1 + 3):
            row = (y - (fy1 - 6)) // 4
            off = 3 if row % 2 else 0
            edge = (x + off) % 9 == 0 or (y - (fy1 - 6)) % 4 == 3
            t = 0.55 - (x - fx0) / (fx1 - fx0) * 0.3 + hash01((x + off) // 9, row, 3) * 0.15
            put(im, x, y, R["stone"][1] if edge else ramp_d("stone", t, x, y))
    # plaster walls with timber frame
    for y in range(fy0, fy1 - 6):
        for x in range(fx0, fx1 + 1):
            t = 0.72 - (x - fx0) / (fx1 - fx0) * 0.38 + fbm(x, y, 4, 10, 2) * 0.08
            put(im, x, y, ramp_d("wall", t, x, y))
    wd = R["wood"]
    for bx in (fx0, fx0 + 40, fx1 - 2):
        for y in range(fy0, fy1 - 6):
            for k in range(3):
                put(im, bx + k, y, wd[4] if k == 0 else wd[3] if k == 1 else wd[2])
    for by in (fy0, fy0 + 20):
        for x in range(fx0, fx1 + 1):
            put(im, x, by, wd[4])
            put(im, x, by + 1, wd[3])
            put(im, x, by + 2, wd[2])
    line(im, fx0 + 3, fy0 + 3, fx0 + 17, fy0 + 19, wd[3])
    line(im, fx1 - 3, fy0 + 3, fx1 - 17, fy0 + 19, wd[2])
    # windows glowing from inside
    for wx in (fx0 + 8, fx1 - 26):
        rect(im, wx - 2, fy0 + 4, wx + 19, fy0 + 18, wd[1])
        for y in range(fy0 + 5, fy0 + 18):
            for x in range(wx, wx + 18):
                t = 0.35 + (y - fy0 - 5) / 13 * 0.6
                put(im, x, y, ramp_d("glow", t, x, y))
        rect(im, wx + 8, fy0 + 5, wx + 9, fy0 + 17, wd[2])
        rect(im, wx, fy0 + 11, wx + 17, fy0 + 11, wd[2])
        put(im, wx + 2, fy0 + 7, "#ffffff")
        put(im, wx + 3, fy0 + 7, "#ffffff")
        put(im, wx + 2, fy0 + 8, "#ffffff")
        # flower box
        rect(im, wx - 3, fy0 + 19, wx + 20, fy0 + 22, wd[2])
        rect(im, wx - 3, fy0 + 19, wx + 20, fy0 + 19, wd[4])
        for k in range(8):
            fx = wx - 2 + k * 3
            ball(im, fx, fy0 + 18, 2, 1.6, "leaf", lo=0.3, hi=0.9)
            put(im, fx, fy0 + 17, ["#ff9fb0", "#fff4a0", "#ffd6dc", "#e76f8a"][k % 4])
    # door with arched top and a lantern
    dx0, dx1 = 47, 61
    for y in range(fy0 + 24, fy1 - 5):
        for x in range(dx0, dx1 + 1):
            top = fy0 + 24 + (3 if x in (dx0, dx1) else 1 if x in (dx0 + 1, dx1 - 1) else 0)
            if y < top:
                continue
            t = 0.55 if x < (dx0 + dx1) / 2 else 0.4
            if (x - dx0) % 4 == 0:
                t = 0.25
            put(im, x, y, ramp_d("wood", t, x, y))
    put(im, dx1 - 3, fy0 + 34, "#ffce50")
    rect(im, dx0 - 3, fy1 - 5, dx1 + 3, fy1 - 3, R["stone"][4])
    rect(im, 66, fy0 + 26, 68, fy0 + 31, wd[1])
    rect(im, 65, fy0 + 28, 69, fy0 + 32, "#ffce50")
    put(im, 66, fy0 + 29, "#ffffff")
    # roof: scalloped tiles, left half in the sun
    rx0, rx1, ry0, ry1 = 2, 105, 10, 57
    ridge0, ridge1 = 22, 85
    for y in range(ry0, ry1 + 1):
        f = (y - ry0) / (ry1 - ry0)
        left = ridge0 + (rx0 - ridge0) * f
        right = ridge1 + (rx1 - ridge1) * f
        for x in range(int(left), int(right) + 1):
            row = (y - ry0) // 6
            ty = (y - ry0) % 6
            off = 3 if row % 2 else 0
            tx = (x + off) % 7
            sun = 1 - (x - left) / max(1, right - left)
            t = 0.28 + sun * 0.42 + f * 0.1
            if ty == 5 or (ty == 4 and tx in (0, 6)):
                t -= 0.28  # tile bottom edge
            elif ty == 0:
                t += 0.12
            put(im, x, y, ramp_d("roof", t, x, y))
    for x in range(ridge0, ridge1 + 1):  # ridge cap
        put(im, x, ry0 - 1, R["roof"][5])
        put(im, x, ry0, R["roof"][4])
    for x in range(rx0, rx1 + 1):  # fascia and eave shadow
        put(im, x, ry1 + 1, wd[1])
        put(im, x, ry1 + 2, wd[2])
    for y in range(fy0, fy0 + 4):
        for x in range(fx0, fx1 + 1):
            mix(im, x, y, "#2c1e4a", 0.45 - (y - fy0) * 0.1)
    # dormer with a round glowing window
    cx = 54
    for y in range(18, 44):
        half = min(12, (y - 18) * 0.9 + 3)
        for x in range(int(cx - half), int(cx + half) + 1):
            if y < 26:
                t = 0.62 if x < cx else 0.4
                put(im, x, y, ramp_d("roof", t, x, y))
            else:
                t = 0.7 - (x - cx + 12) / 24 * 0.35
                put(im, x, y, ramp_d("wall", t, x, y))
    ball(im, cx, 34, 5.5, 5.5, "glow", lo=0.4, hi=1.0)
    for a in range(0, 360, 10):
        put(im, cx + math.cos(math.radians(a)) * 6, 34 + math.sin(math.radians(a)) * 6, wd[2])
    line(im, cx - 6, 34, cx + 6, 34, wd[2])
    line(im, cx, 28, cx, 40, wd[2])
    # chimney
    for y in range(0, 30):
        for x in range(76, 88):
            t = 0.65 if x < 81 else 0.35
            if (y // 4 + (x // 4)) % 2 == 0 and y % 4 == 3:
                t -= 0.2
            put(im, x, y, ramp_d("stone", t, x, y))
    rect(im, 75, 0, 88, 2, R["stone"][1])
    # ivy climbing the left corner
    for k in range(26):
        y = fy1 - 6 - k * 1.6
        x = fx0 + 1 + math.sin(k * 0.7) * 2
        ball(im, x, y, 2.2, 1.8, "leaf", lo=0.25, hi=0.95)
        if k % 5 == 2:
            put(im, x, y - 1, "#ff9fb0")
    outline(im)
    # light the glow after the outline so it can spill
    for wx in (fx0 + 17, fx1 - 17):
        glow(im, wx, fy0 + 12, 14, "#ffce50", 0.35)
    glow(im, 67, fy0 + 30, 9, "#ffce50", 0.55)
    glow(im, cx, 34, 10, "#ffce50", 0.35)
    return im


# ------------------------------------------------------------------ tree
def blossom_tree(seed=3):
    W, H = 84, 92
    im = new(W, H)
    wd = R["wood"]
    # trunk with roots
    for y in range(50, 90):
        half = 4 + max(0, (y - 78)) * 0.7
        cx = 42 + math.sin(y * 0.12) * 2
        for x in range(int(cx - half), int(cx + half) + 1):
            t = 0.7 - (x - cx + half) / (2 * half) * 0.55
            if hash01(x, y // 3, seed) < 0.15:
                t -= 0.2
            put(im, x, y, ramp_d("wood", t, x, y))
    for (sx, ex, ey) in ((40, 26, 48), (44, 60, 44), (42, 40, 34)):
        line(im, sx, 60, ex, ey, wd[3])
        line(im, sx + 1, 60, ex + 1, ey, wd[2])
    # canopy: clusters lit top-left, rim light on the left edges
    rnd = random.Random(seed)
    blobs = [(42, 32, 22, 18), (24, 40, 14, 12), (60, 40, 14, 12), (34, 20, 14, 11), (52, 22, 14, 11),
             (42, 46, 16, 9)]
    for (bx, by, rx, ry) in blobs:
        ball(im, bx + 2, by + 3, rx, ry, "leaf", lo=0.0, hi=0.35)
    for (bx, by, rx, ry) in blobs:
        ball(im, bx, by, rx, ry, "leaf", lo=0.15, hi=0.95, spread=1.2)
    for _ in range(220):  # leaf texture: little lit crescents
        a = rnd.random() * 6.283
        bx, by, rx, ry = rnd.choice(blobs)
        r = rnd.random() ** 0.5
        x, y = bx + math.cos(a) * rx * r, by + math.sin(a) * ry * r
        if im.getpixel((int(x), int(y)))[3] == 0:
            continue
        lit = (x - 42) + (y - 32) < 0
        put(im, x, y, R["leaf"][6 if lit else 3])
        put(im, x + 1, y + 1, R["leaf"][2])
    for _ in range(70):  # blossoms
        bx, by, rx, ry = rnd.choice(blobs)
        a = rnd.random() * 6.283
        r = rnd.random() ** 0.6 * 0.9
        x, y = bx + math.cos(a) * rx * r, by + math.sin(a) * ry * r
        lit = (x - 42) + (y - 32) < 6
        put(im, x, y, R["blossom"][4 if lit else 2])
        put(im, x + 1, y, R["blossom"][3 if lit else 1])
        put(im, x, y + 1, R["blossom"][2 if lit else 0])
    outline(im)
    return im


# ------------------------------------------------------------------ scarecrow (the icon hero)
def scarecrow():
    W, H = 48, 84
    im = new(W, H)
    wd = R["wood"]
    rect(im, 23, 40, 25, 83, wd[3])
    rect(im, 23, 40, 23, 83, wd[4])
    rect(im, 25, 40, 25, 83, wd[2])
    # crossbar + cape sleeves
    rect(im, 3, 36, 45, 38, wd[3])
    rect(im, 3, 36, 45, 36, wd[4])
    for y in range(34, 64):
        for x in range(6, 43):
            half = 10 + (y - 34) * 0.5
            if abs(x + 0.5 - 24) > half:
                continue
            hem = 58 + int(3 * math.sin(x * 0.9))  # scalloped hem
            if y > hem:
                continue
            fold = math.sin((x - 24) * 0.55 + (y - 34) * 0.08)  # soft vertical folds
            t = 0.62 - (x - 6) / 37 * 0.4 + fold * 0.12
            put(im, x, y, ramp_d("cape", t, x, y))
            if y == hem or y == hem - 1:
                put(im, x, y, R["gold"][3] if x < 24 else R["gold"][2])  # gold trim
        put(im, 24 - int(10 + (y - 34) * 0.5), y, R["cape"][5])  # rim light on the sunny edge
    for (x0, x1, lit) in ((4, 13, 0.6), (35, 44, 0.32)):  # sleeves
        for y in range(35, 45):
            for x in range(x0, x1 + 1):
                if y > 41 and (x + y) % 3 == 0:
                    continue
                put(im, x, y, ramp_d("cape", lit + (0.1 if y < 37 else 0), x, y))
        for x in range(x0, x1 + 1):
            put(im, x, 44, R["gold"][2])
    rect(im, 28, 48, 32, 52, R["straw"][2])  # patch
    rect(im, 28, 48, 32, 48, R["straw"][4])
    put(im, 30, 50, R["wood"][1])
    for hx in (2, 45):  # straw hands
        for k in range(5):
            put(im, hx + (k % 2), 37 + k, R["straw"][4 if k % 2 else 3])
    # straw collar
    for x in range(14, 35):
        for k in range(3 + int(hash01(x, 2, 1) * 3)):
            put(im, x, 32 + k, R["straw"][4 - (x % 3 == 0) - (k > 2)])
    ball(im, 24, 44, 2.4, 2.4, "mint", lo=0.3, hi=1.0)  # gem brooch
    put(im, 23, 43, "#ffffff")
    # pumpkin head
    ball(im, 24, 22, 12, 10.5, "pumpkin", lo=0.12, hi=0.92)
    for rx in (17, 24, 31):  # ribs
        for y in range(13, 32):
            if im.getpixel((rx, y))[3]:
                mix(im, rx, y, "#7a2a18", 0.35)
    # carved glowing face
    for (ex, ey, d) in ((18, 20, 1), (30, 20, -1)):
        for k in range(5):
            for j in range(k + 1):
                put(im, ex + d * (j - 2) + (0 if d > 0 else 0), ey - 2 + k, ramp_d("glow", 0.55 + k * 0.1, ex + j, ey + k))
    for x in range(16, 33):  # jagged mouth
        top = 26 + (1 if (x // 2) % 2 else 0)
        for y in range(top, 30 - (1 if x in (16, 32) else 0)):
            put(im, x, y, ramp_d("glow", 0.5 + (y - 26) * 0.12, x, y))
    for x in (19, 23, 27, 31):
        put(im, x, 29, R["pumpkin"][2])
    # hat
    for x in range(4, 45):
        for y in range(10, 14):
            t = 0.75 - (x - 4) / 41 * 0.45
            if y == 13:
                t -= 0.25
            put(im, x, y, ramp_d("straw", t, x, y))
    for y in range(0, 11):
        half = 8 - max(0, 3 - y) * 1.2
        for x in range(int(24 - half), int(24 + half) + 1):
            t = 0.8 - (x - 24 + half) / (2 * half) * 0.4
            if (x + y) % 5 == 0:
                t -= 0.1
            put(im, x, y, ramp_d("straw", t, x, y))
    rect(im, 16, 8, 32, 9, R["red"][2])
    put(im, 16, 8, R["red"][3])
    for (sx, sy) in ((22, 0), (26, 0)):  # sprout on top
        ball(im, sx + (-3 if sx < 24 else 3), sy - 0, 3, 2, "leaf", lo=0.4, hi=1.0)
    im2 = new(W, H + 4)
    im2.alpha_composite(im, (0, 4))
    im = im2
    rect(im, 24, 0, 24, 5, R["leaf"][3])
    # pitchfork in the right hand
    for i in range(48):
        x, y = 46 - i * 0.18, 72 - i
        put(im, x, y, wd[4])
        put(im, x + 1, y, wd[2])
    for k in range(-4, 5):
        put(im, 38 + k, 24, R["stone"][5])
    for t in (-4, 0, 4):
        for k in range(1, 9):
            put(im, 38 + t, 24 - k, R["stone"][6 if k > 1 else 4])
    outline(im)
    glow(im, 24, 27, 15, "#ffce50", 0.4)
    return im


# ------------------------------------------------------------------ people and animals
def farmer(frame=0):
    W, H = 26, 40
    im = new(W, H)
    step = 1 if frame else 0
    cb, cr, sk = R["cloth_blue"], R["cloth_red"], R["skin"]
    rect(im, 9, 30, 11, 36 - step, cb[1])
    rect(im, 14, 30, 16, 35 + step, cb[1])
    rect(im, 8, 37 - step, 12, 38 - step, R["wood"][1])
    rect(im, 13, 36 + step, 17, 37 + step, R["wood"][1])
    for y in range(17, 31):  # shirt
        for x in range(7, 19):
            put(im, x, y, ramp_d("cloth_red", 0.8 - (x - 7) / 12 * 0.55, x, y))
    for y in range(21, 32):  # overalls
        for x in range(8, 18):
            put(im, x, y, ramp_d("cloth_blue", 0.85 - (x - 8) / 10 * 0.6, x, y))
    rect(im, 9, 18, 10, 21, cb[3])
    rect(im, 15, 18, 16, 21, cb[2])
    put(im, 10, 22, "#ffce50")
    put(im, 15, 22, "#ffce50")
    rect(im, 10, 25, 15, 27, cb[2])
    for y in range(18, 27):  # arms
        put(im, 6, y, ramp_d("cloth_red", 0.85, 6, y))
        put(im, 19, y, ramp_d("cloth_red", 0.35, 19, y))
    put(im, 6, 27, sk[2])
    put(im, 19, 27, sk[1])
    # watering can in the right hand
    for y in range(26, 33):
        for x in range(18, 25):
            put(im, x, y, ramp_d("stone", 0.85 - (x - 18) / 7 * 0.4 - (y - 26) * 0.03, x, y))
    line(im, 24, 28, 25, 24, R["stone"][4])
    put(im, 25, 23, R["stone"][5])
    # head
    ball(im, 13, 13, 4.6, 4.4, "skin", lo=0.2, hi=1.0)
    put(im, 15, 13, "#1e101e")
    put(im, 16, 15, sk[1])
    rect(im, 9, 16, 17, 17, cr[3])  # scarf
    # straw hat
    for x in range(3, 24):
        put(im, x, 9, ramp_d("straw", 0.85 - (x - 3) / 21 * 0.45, x, 9))
        put(im, x, 10, ramp_d("straw", 0.6 - (x - 3) / 21 * 0.4, x, 10))
    for y in range(3, 9):
        for x in range(8, 19):
            put(im, x, y, ramp_d("straw", 0.85 - (x - 8) / 11 * 0.4, x, y))
    rect(im, 8, 7, 18, 8, R["red"][2])
    outline(im)
    return im


def hen(frame=0, flip=False):
    W, H = 16, 14
    im = new(W, H)
    ball(im, 7, 8, 5.4, 4.2, "white", lo=0.2, hi=1.0)
    for (x, y) in ((1, 4), (2, 5), (1, 6), (2, 3)):
        put(im, x, y, R["white"][2 + (x % 2)])
    hx, hy = (12, 3) if frame == 0 else (12, 8)
    ball(im, hx, hy, 2.4, 2.4, "white", lo=0.4, hi=1.0)
    put(im, hx, hy - 3, R["red"][2])
    put(im, hx + 1, hy - 3, R["red"][3])
    put(im, hx + 3, hy, "#ffce50")
    put(im, hx + 1, hy - 1, "#1e101e")
    put(im, hx + 2, hy + 2, R["red"][2])
    for x in (6, 9):
        put(im, x, 13, "#f0a02e")
        put(im, x, 12, "#b8661e")
    outline(im)
    if flip:
        im = im.transpose(0)
    return im


# ------------------------------------------------------------------ farm structures
def well():
    W, H = 40, 54
    im = new(W, H)
    wd = R["wood"]
    for x in (5, 33):
        rect(im, x, 12, x + 1, 40, wd[3])
        put(im, x, 12, wd[4])
    for y in range(0, 14):  # little roof
        half = 6 + y * 1.2
        for x in range(int(20 - half), int(20 + half) + 1):
            t = 0.75 - (x - 20 + half) / (2 * half) * 0.5
            if y % 4 == 3:
                t -= 0.25
            put(im, x, y, ramp_d("roof", t, x, y))
    line(im, 5, 21, 34, 21, wd[2])
    rect(im, 19, 22, 20, 30, R["straw"][2])
    for y in range(30, 36):
        for x in range(16, 24):
            put(im, x, y, ramp_d("wood", 0.75 - (x - 16) / 8 * 0.4, x, y))
    for y in range(36, 53):  # stone ring
        for x in range(1, 39):
            row = (y - 36) // 4
            off = 3 if row % 2 else 0
            edge = (x + off) % 7 == 0 or (y - 36) % 4 == 3
            t = 0.8 - (x / 39) * 0.45
            put(im, x, y, R["stone"][2] if edge else ramp_d("stone", t, x, y))
    for x in range(4, 36):
        put(im, x, 36, R["water"][2] if x < 20 else R["water"][1])
        put(im, x, 37, R["water"][3] if x % 5 == 0 else R["water"][1])
    outline(im)
    return im


def fence(length):
    W, H = length, 20
    im = new(W, H)
    wd = R["wood"]
    for rail_y in (7, 13):
        for x in range(W):
            put(im, x, rail_y, wd[4])
            put(im, x, rail_y + 1, wd[3])
            put(im, x, rail_y + 2, wd[2])
    posts = list(range(1, W - 8, 16)) + [W - 3]
    for px in posts:
        for y in range(2, 20):
            put(im, px, y, wd[4])
            put(im, px + 1, y, wd[3])
            put(im, px + 2, y, wd[2])
        put(im, px + 1, 1, wd[5])
    outline(im)
    return im


def dead_tree(seed=1):
    W, H = 40, 52
    im = new(W, H)
    rnd = random.Random(seed)

    def branch(x, y, ang, length, width):
        for i in range(int(length)):
            x += math.cos(ang)
            y += math.sin(ang)
            ang += rnd.uniform(-0.12, 0.12)
            for k in range(int(width)):
                put(im, x + k, y, R["dust"][2] if k else R["dust"][4])
            if width > 1.2 and rnd.random() < 0.08:
                branch(x, y, ang + rnd.choice((-0.8, 0.8)), length * 0.5, width * 0.6)
            width = max(1, width * 0.985)
    branch(20, 51, -math.pi / 2, 34, 4)
    outline(im)
    return im


def rock(seed=2):
    im = new(20, 14)
    ball(im, 10, 8, 8, 5.5, "stone", lo=0.1, hi=0.8)
    ball(im, 6, 9, 4, 3, "stone", lo=0.2, hi=0.85)
    outline(im)
    return im


# ------------------------------------------------------------------ crops (32 x 44, base on the bed)
def wheat(stage, seed=1):
    W, H = 32, 44
    im = new(W, H)
    rnd = random.Random(seed)
    stalks = []
    for row in range(3):  # back, middle and front rows of stalks
        for i in range(5):
            x = 5 + i * 5 + rnd.uniform(-1.5, 1.5) + (2 if row % 2 else 0)
            base = 32 + row * 4
            top = base - (17 if stage == 3 else 10) + rnd.randint(-2, 2)
            stalks.append((x, base, top, rnd.uniform(-0.15, 0.2), row))
    for (x, base, top, lean, row) in stalks:
        for y in range(top, base + 1):
            xx = x + (base - y) * lean
            put(im, xx, y, (R["straw"][2] if row < 2 else R["straw"][3]) if stage == 3 else R["leaf"][3 + (row > 0)])
        if stage == 3:
            hx = x + (base - top) * lean
            for k in range(7):
                lit = 0.98 - k * 0.05 - (0.25 if row == 0 else 0)
                put(im, hx - 1, top - k + 1, ramp_d("straw", lit, hx, top - k))
                put(im, hx, top - k, ramp_d("straw", lit - 0.2, hx, top - k))
                if k % 2 == 0:
                    put(im, hx + 1, top - k + 1, R["straw"][3])
            put(im, hx, top - 8, R["straw"][5])
        else:
            put(im, x + (base - top) * lean - 1, top, R["leaf"][5])
    outline(im)
    return im


def ember_pumpkin(stage):
    W, H = 32, 44
    im = new(W, H)
    if stage < 3:
        for (lx, ly) in ((10, 34), (20, 33), (15, 30)):
            ball(im, lx, ly, 4.5, 3.2, "leaf", lo=0.2, hi=0.95)
        if stage == 2:
            ball(im, 16, 38, 6, 4.5, "pumpkin", lo=0.15, hi=0.7)
        outline(im)
        return im
    for (lx, ly) in ((5, 36), (27, 35)):
        ball(im, lx, ly, 5, 3.2, "leaf", lo=0.2, hi=0.95)
    ball(im, 16, 32, 12, 9.5, "pumpkin", lo=0.1, hi=0.95)
    for rx in (9, 16, 23):
        for y in range(24, 42):
            if im.getpixel((rx, y))[3]:
                mix(im, rx, y, "#7a2a18", 0.4)
    # ember veins glowing through the skin
    for (x0, y0) in ((12, 28), (19, 30), (15, 35)):
        for k in range(4):
            put(im, x0 + k * (1 if k % 2 else 0), y0 + k, "#fff4a0" if k < 2 else "#ffce50")
    rect(im, 15, 20, 17, 23, R["leaf"][2])
    put(im, 15, 20, R["leaf"][4])
    line(im, 18, 21, 21, 19, R["leaf"][3])
    outline(im)
    glow(im, 16, 32, 13, "#ff9628", 0.25)
    return im


def moon_turnip(stage):
    W, H = 32, 44
    im = new(W, H)
    leaves = 3 if stage < 2 else 5
    for i in range(leaves):
        ang = -math.pi / 2 + (i - (leaves - 1) / 2) * 0.45
        for k in range(10 if stage >= 2 else 6):
            x = 16 + math.cos(ang) * k
            y = 34 + math.sin(ang) * k
            ball(im, x, y, 1.6, 1.4, "leaf", lo=0.3, hi=0.95) if k > 3 else put(im, x, y, R["leaf"][3])
    if stage >= 2:
        ball(im, 16, 38, 7, 5.5, "stone", lo=0.5, hi=1.0)
        ball(im, 16, 36, 7, 3, "blossom", lo=0.1, hi=0.6, mask=lambda x, y: y < 37)
    outline(im)
    if stage >= 2:
        glow(im, 16, 38, 10, "#c2b0e0", 0.3)
    return im


def sprout(seed=4):
    W, H = 32, 44
    im = new(W, H)
    for (x, y) in ((8, 34), (16, 34), (24, 34), (8, 26), (16, 26), (24, 26)):
        put(im, x, y + 4, R["leaf"][2])
        put(im, x, y + 3, R["leaf"][3])
        put(im, x - 1, y + 2, R["leaf"][5])
        put(im, x + 1, y + 2, R["leaf"][4])
        put(im, x - 2, y + 1, R["leaf"][5])
        put(im, x + 2, y + 2, R["leaf"][3])
    outline(im)
    return im


def frost_cabbage():
    W, H = 32, 44
    im = new(W, H)
    ball(im, 16, 34, 11, 8, "leaf", lo=0.1, hi=0.7)
    ball(im, 16, 33, 7, 5.5, "mint", lo=0.3, hi=1.0)
    for a in range(0, 360, 45):
        x = 16 + math.cos(math.radians(a)) * 9
        y = 34 + math.sin(math.radians(a)) * 6
        put(im, x, y, R["mint"][4])
    outline(im)
    return im


# ------------------------------------------------------------------ HUD icons
def coin_icon():
    im = new(20, 20)
    ball(im, 10, 10, 8.6, 8.6, "gold", lo=0.15, hi=1.0)
    for a in range(0, 360, 6):  # rim
        x = 10 + math.cos(math.radians(a)) * 6.4
        y = 10 + math.sin(math.radians(a)) * 6.4
        put(im, x, y, R["gold"][2] if a < 200 else R["gold"][3])
    rect(im, 9, 7, 10, 13, R["gold"][2])  # embossed sprout
    put(im, 8, 7, R["gold"][2])
    put(im, 7, 6, R["gold"][2])
    put(im, 11, 7, R["gold"][2])
    put(im, 12, 6, R["gold"][2])
    put(im, 6, 5, "#ffffff")
    put(im, 5, 6, "#fff0a8")
    outline(im)
    return im


def dew_icon():
    im = new(18, 22)
    for y in range(1, 21):
        w = (y - 1) * 0.55 if y < 12 else math.sqrt(max(0, 7.5 ** 2 - (y - 13) ** 2))
        for x in range(18):
            if abs(x + 0.5 - 9) <= w:
                put(im, x, y, "#5a74b0")
    ball(im, 9, 13, 7.5, 7.5, "water", lo=0.4, hi=1.0, mask=lambda x, y: True)
    for y in range(1, 21):
        for x in range(18):
            if im.getpixel((x, y))[3]:
                v = 1 - (y / 22)
                if x < 9 and dither(x, y, 0.3 + v * 0.4):
                    put(im, x, y, "#7ad8e8")
    put(im, 6, 10, "#ffffff")
    put(im, 6, 11, "#ffffff")
    put(im, 7, 9, "#d8f8ff")
    outline(im)
    return im


def sickle_icon():
    """Bound wheat sheaf: the season event."""
    im = new(22, 22)
    for i in range(7):
        spread = (i - 3) * 0.55
        for y in range(8, 21):
            k = (y - 13) / 7
            x = 11 + spread * (abs(k) * 2 if y > 13 else (13 - y) / 3)
            put(im, x, y, R["straw"][3 if i < 4 else 2])
        tx = 11 + spread * 5 / 3 * 1.6
        for k in range(6):
            put(im, tx, 7 - k, R["straw"][5 if k < 3 else 4])
            if k % 2 == 0:
                put(im, tx + 1, 7 - k, R["straw"][3])
    rect(im, 8, 13, 14, 14, R["red"][2])
    put(im, 8, 13, R["red"][3])
    outline(im)
    return im
