#!/usr/bin/env python3
"""Bloom brand art: app icon variants, the DUSTBLOOM logo and the loading screen.

    python3 art/bloom/brand.py OUT_DIR

Everything is drawn at true pixel-art size, in the same palette and outline
style as the game sprites (sprites.py), then scaled up with nearest neighbour.
"""
import math, os, random, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprites as S  # noqa: E402
from sprites import Canvas, C, hexc  # noqa: E402

S.build_all()
SP = S.SPRITES


def paste(dst, name_or_im, x, y, flip=False):
    im = SP[name_or_im] if isinstance(name_or_im, str) else name_or_im
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    dst.im.alpha_composite(im, (int(x), int(y)))


def mix(a, b, t):
    a, b = hexc(a), hexc(b)
    return '#%02x%02x%02x' % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(cv, stops, y0=0, y1=None, dither=True):
    """Vertical banded gradient with checker dithering between bands (pixel-art style)."""
    y1 = cv.h - 1 if y1 is None else y1
    n = len(stops) - 1
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0) * n
        i = min(n - 1, int(t))
        f = t - i
        for x in range(cv.w):
            c = stops[i + 1] if (dither and f > 0.5 and (x + y) % 2 == 0 and f < 0.85) or f >= 0.85 else stops[i]
            cv.put(x, y, c)


def sunburst(cv, cx, cy, rays, color, a, r0=0):
    for y in range(cv.h):
        for x in range(cv.w):
            ang = math.atan2(y - cy, x - cx)
            if int((ang + math.pi) / (2 * math.pi) * rays * 2) % 2 == 0 and math.hypot(x - cx, y - cy) > r0:
                cv.put(x, y, color, a)


def sparkle(cv, x, y, big=False, c='white'):
    cv.put(x, y, c)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        cv.put(x + dx, y + dy, c, 200)
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            cv.put(x + dx, y + dy, c, 120)


def island(cv, cx, top, rx, depth, seed=3, split=True):
    """Floating island: grass top, layered cliff tapering into a point.
    Left half still dust, right half in bloom: the game's whole promise in one shape."""
    rnd = random.Random(seed)
    ry = max(2.5, rx * 0.26)
    body = Canvas(cv.w, cv.h)
    # cliff: rows taper to a tip
    for k in range(depth):
        t = k / depth
        w = rx * (1 - t ** 1.6) + 0.5
        y = top + ry * 0.6 + k
        for x in range(int(cx - w), int(cx + w) + 1):
            dusty = split and x < cx - (k % 3 == 0)
            band = (k // 2) % 3
            if dusty:
                col = ('ud1', 'ud2', 'ud0')[band]
            else:
                col = ('d1', 'd2', 'd0')[band]
            if x > cx + w - 2:
                col = 'ud0' if dusty else 'd0'
            body.put(x, y, col)
    # grass / dust cap
    body.disc(cx, top + ry * 0.4, rx + 0.5, ry, 'd0')
    for y in range(int(top - ry) - 1, int(top + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - top) / ry) ** 2 <= 1:
                edge = abs(x - (cx - 1)) <= 1 and rnd.random() < 0.6
                dusty = split and (x < cx - 1 or (edge and rnd.random() < 0.5))
                if dusty:
                    col = 'u2' if (x + y) % 2 else 'u1b'
                    if y < top - ry * 0.4:
                        col = 'u3'
                else:
                    col = 'g1' if (x + y) % 2 else 'g1b'
                    if y < top - ry * 0.4:
                        col = 'g2'
                body.put(x, y, col)
    # grass lip hanging over the cliff on the green side
    for x in range(int(cx), int(cx + rx)):
        if rnd.random() < 0.5:
            yy = top + ry * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2))
            body.put(x, yy + 0.5, 'g0')
    # scatter: flowers on green, pebbles and cracks on dust
    for _ in range(int(rx * 1.6)):
        a = rnd.random() * math.pi * 2
        r = math.sqrt(rnd.random())
        x = cx + math.cos(a) * rx * 0.85 * r
        y = top + math.sin(a) * ry * 0.7 * r
        if split and x < cx - 1:
            body.put(x, y, 'ud1')
        else:
            body.put(x, y, rnd.choice(('white', 'berry_l', 'gold', 'water_l', 'g3')))
    body.outline('ink')
    cv.im.alpha_composite(body.im)


# ---------------------------------------------------------------- app icon

ICON_BG = {
    'sky': (['#1f6fd0', '#2f8fe8', '#4fc4ec', '#8fe0f7'], '#ffffff', 46),
    'peach': (['#e0497a', '#ff7a8f', '#ffa86e', '#ffd88a'], '#fff4c8', 60),
    'night': (['#241a4a', '#3b2a78', '#6a3fa0', '#c06aa8'], '#ffd040', 40),
}


def icon(variant):
    stops, ray, ray_a = ICON_BG[variant]
    cv = Canvas(32, 32)
    gradient(cv, stops, dither=False)
    sunburst(cv, 16, 14, 8, ray, ray_a // 2, r0=3)
    cv.disc(16, 15, 10, 10, ray, 40)
    cv.disc(16, 15, 7, 7, ray, 55)
    island(cv, 16, 25, 12.5, 6, seed=7)
    hero = big_eyed_hero()
    paste(cv, 'bloom_pick_3', 19, 11)
    paste(cv, hero, 8, 4)
    paste(cv, 'bloom_item_coin', 3, 3)
    for (x, y, b) in ((27, 4, True), (24, 9, False), (5, 18, False), (28, 15, False)):
        sparkle(cv, x, y, b, 'white' if variant != 'night' else 'gold_l')
    for (x, y) in ((24, 21), (27, 22), (21, 20)):
        cv.put(x, y, 'berry_l'); cv.put(x + 1, y, 'berry_l', 160)
    return cv.im


def big_eyed_hero():
    """The hero with open, shiny eyes and an open smile: faces sell icons."""
    cv = Canvas(16, 24)
    cv.im.alpha_composite(SP['bloom_hero_idle_0'])
    x, by = 8, 21
    cv.rect(x - 3, by - 8, x + 3, by - 3, 'cream')          # wipe the small face
    for ex in (x - 3, x + 2):
        cv.rect(ex, by - 8, ex + 1, by - 6, 'ink')
        cv.put(ex, by - 8, 'white')
    cv.put(x - 4, by - 5, 'cheek'); cv.put(x + 4, by - 5, 'cheek')
    cv.put(x - 1, by - 4, 'ink'); cv.put(x, by - 4, 'ink'); cv.put(x + 1, by - 4, 'ink')
    cv.put(x, by - 3, 'berry_d')
    return cv.im


# ---------------------------------------------------------------- logo

GLYPHS = {
    'D': ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
    'U': ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'S': [".#####", "##....", "##....", ".####.", "....##", "....##", "#####."],
    'T': ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    'B': ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "#####."],
    'L': ["##....", "##....", "##....", "##....", "##....", "##....", "######"],
    'O': [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'M': ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##"],
}


def word(cv, text, x, y, ramp, gap=1):
    """Draw a word in the bold glyphs with a vertical colour ramp; returns glyph x positions."""
    xs = []
    for ch in text:
        g = GLYPHS[ch]
        xs.append(x)
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '#':
                    cv.put(x + gx, y + gy, ramp[gy])
        x += len(g[0]) + gap
    return xs


def word_width(text, gap=1):
    return sum(len(GLYPHS[c][0]) for c in text) + gap * (len(text) - 1)


DUST_RAMP = ['#ffffff', '#efe4f6', '#d9c9e6', '#c4b0d6', '#ae98c4', '#9a82b4', '#8670a2']
BLOOM_RAMP = ['#fff4f8', '#ffd0e0', '#ffa4c0', '#ff7ea4', '#f45a88', '#e04276', '#c82c62']


def logo():
    """Stacked logo: small dusty 'DUST' over a big blooming 'BLOOM'; a sprout with a
    flower grows out of the second O. Ink outline and a deep shadow, like the sprites."""
    bw = word_width("BLOOM")
    dw = word_width("DUST")
    top = 7
    cv = Canvas(bw + 8, top + 7 + 2 + 7 + 6)
    word(cv, "DUST", 4, top, DUST_RAMP)
    xs = word(cv, "BLOOM", 4, top + 9, BLOOM_RAMP)
    # sprout and a five-petal flower growing from the M, filling the corner next to DUST
    fx = xs[4] + 3
    cv.rect(fx, top + 6, fx, top + 8, 'l1')
    cv.disc(fx - 2, top + 6.5, 2.2, 1.2, 'l2'); cv.put(fx - 3, top + 6, 'l3')
    cv.disc(fx + 2.5, top + 5.5, 2.2, 1.2, 'l3'); cv.put(fx + 3, top + 5, 'l4')
    for (dx, dy) in ((0, -2), (-2, -1), (2, -1), (-1, 1), (1, 1)):
        cv.disc(fx + 0.5 + dx, top + 2 + dy, 1.3, 1.3, 'berry_l')
    cv.put(fx, top + 2, 'gold'); cv.put(fx + 1, top + 2, 'gold'); cv.put(fx, top + 1, 'gold_l')
    cv.outline('ink')
    out = Canvas(cv.w, cv.h + 2)
    sh = cv.im.copy()
    px = sh.load()
    for yy in range(sh.height):
        for xx in range(sh.width):
            if px[xx, yy][3]:
                px[xx, yy] = hexc('#1a1230')
    out.im.alpha_composite(sh, (0, 2))
    out.im.alpha_composite(sh, (0, 1))
    out.im.alpha_composite(cv.im, (0, 0))
    sparkle(out, 2, top + 12, False)
    sparkle(out, cv.w - 2, top + 9, True)
    return out.im


# ---------------------------------------------------------------- loading screen

SPLASH_PT = 6  # points per art pixel on the loading screen (twice the game zoom: chunky, readable)


def splash_bg():
    """66 x 142 px, shown at 6 pt per pixel (393 x 852 pt): sky-sea, drifting islands,
    the main island half dust / half bloom. The hero and logo are animated on top in code."""
    W, H = 66, 142
    cv = Canvas(W, H)
    gradient(cv, ['#2c7fe0', '#3aa4ea', '#4fc4ec', '#6fd4f2', '#4fc4ec', '#3eaee0'], dither=False)
    rnd = random.Random(11)
    sunburst(cv, 33, 22, 9, '#ffffff', 22, r0=4)
    for _ in range(46):
        x, y = rnd.randrange(W), rnd.randrange(58, H)
        cv.rect(x, y, x + rnd.choice((1, 2)), y, 'water_l', 170)
    for (x, y, r, sd, sp) in ((8, 58, 6, 1, True), (57, 64, 5, 2, False), (56, 136, 6, 4, True), (9, 134, 5, 5, False)):
        island(cv, x, y, r, 4, seed=sd, split=sp)
    for (x, y, r) in ((12, 44, 7), (56, 40, 5)):
        cv.disc(x, y, r, r * 0.45, 'white', 150)
        cv.disc(x + r * 0.6, y - 1, r * 0.6, r * 0.4, 'white', 170)
    island(cv, 33, 90, 27, 15, seed=21)
    paste(cv, 'bloom_stump', 10, 76)
    paste(cv, 'bloom_rock', 18, 78)
    paste(cv, 'bloom_tree', 43, 62)
    paste(cv, 'bloom_bush_berry', 50, 80)
    for (x, y, n) in ((38, 91, 'pink'), (46, 93, 'yellow'), (54, 89, 'white'), (40, 84, 'blue')):
        paste(cv, 'bloom_flower_' + n, x, y)
    return cv.im


def splash_preview(bg, lg, out):
    """Phone-size mockup (1179 x 2556, @3x) of the loading screen as the game will draw it."""
    from PIL import ImageDraw, ImageFont
    P = 3                    # pixels per point
    A = SPLASH_PT * P        # pixels per art pixel
    img = bg.resize((bg.width * A, bg.height * A), Image.NEAREST)
    L = lg.resize((lg.width * A, lg.height * A), Image.NEAREST)
    img.alpha_composite(L, ((img.width - L.width) // 2, 70 * P))
    hero = big_eyed_hero().resize((16 * A, 24 * A), Image.NEAREST)
    pk = SP['bloom_pick_3']
    img.alpha_composite(pk.resize((pk.width * A, pk.height * A), Image.NEAREST), (img.width // 2 + 3 * A, (90 - 22) * A))
    img.alpha_composite(hero, (img.width // 2 - 8 * A, (90 - 21) * A))
    paste_h = SP['bloom_helper_pink_idle_0']
    img.alpha_composite(paste_h.resize((paste_h.width * A, paste_h.height * A), Image.NEAREST), (img.width // 2 + 10 * A, (90 - 13) * A))
    d = ImageDraw.Draw(img)
    fp = os.path.join(S.ROOT, 'client', 'Dustbloom', 'Fonts', 'Rubik-Bold.ttf')

    def outlined(text, y, size, fill):
        f = ImageFont.truetype(fp, size * P)
        w = d.textlength(text, font=f)
        x = (img.width - w) / 2
        o = 2 * P
        for dx in range(-o, o + 1, P):
            for dy in range(-o, o + 2 * P, P):
                d.text((x + dx, y * P + dy), text, font=f, fill=hexc('ink'))
        d.text((x, y * P), text, font=f, fill=fill)

    outlined("Преврати пыль в цветущие острова", 70 + lg.height * SPLASH_PT + 12, 17, hexc('white'))
    # vine progress bar (pt)
    bx, by, bw, bh = 56, 676, 393 - 112, 18
    d.rounded_rectangle(((bx - 3) * P, (by - 3) * P, (bx + bw + 3) * P, (by + bh + 3) * P), radius=12 * P, fill=hexc('ink'))
    d.rounded_rectangle((bx * P, by * P, (bx + bw) * P, (by + bh) * P), radius=9 * P, fill=hexc('#3a2f5c'))
    fw = int(bw * 0.72)
    d.rounded_rectangle((bx * P, by * P, (bx + fw) * P, (by + bh) * P), radius=9 * P, fill=hexc('l2'))
    d.rounded_rectangle(((bx + 4) * P, (by + 3) * P, (bx + fw - 4) * P, (by + 7) * P), radius=3 * P, fill=hexc('l3'))
    for k in range(bx + 18, bx + fw - 14, 34):
        d.ellipse((k * P, (by - 7) * P, (k + 12) * P, (by + 1) * P), fill=hexc('l3'), outline=hexc('ink'), width=2 * P)
    fl = SP['bloom_flower_pink']
    fl = fl.resize((fl.width * A // 2 * 2, fl.height * A // 2 * 2), Image.NEAREST)
    img.alpha_composite(fl, ((bx + fw) * P - fl.width // 2, (by + bh // 2) * P - fl.height + 4 * A))
    outlined("Острова просыпаются…  72%", by + bh + 12, 14, hexc('cream'))
    outlined("Нажми, чтобы играть", 772, 22, hexc('gold'))
    img.save(out)
    img.resize((img.width // 3, img.height // 3), Image.LANCZOS).save(out.replace('.png', '-small.png'))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    icons = []
    for v in ICON_BG:
        im = icon(v)
        big = im.resize((1024, 1024), Image.NEAREST)
        big.save(os.path.join(out, 'icon-%s.png' % v))
        icons.append(big)
    lg = logo()
    lg.resize((lg.width * 12, lg.height * 12), Image.NEAREST).save(os.path.join(out, 'logo.png'))
    bg = splash_bg()
    bg.save(os.path.join(out, 'splash-bg-1x.png'))
    splash_preview(bg, lg, os.path.join(out, 'splash.png'))
    # icon board: each variant big, then as it looks on a home screen (60 pt @3x = 180 px, rounded)
    board = Image.new('RGBA', (3 * 380 + 40, 600), hexc('#1e1e24'))
    from PIL import ImageDraw
    for i, big in enumerate(icons):
        m = Image.new('L', (340, 340), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 339, 339), radius=76, fill=255)
        b = big.resize((340, 340), Image.NEAREST)
        board.paste(b, (20 + i * 380, 20), m)
        m2 = Image.new('L', (180, 180), 0)
        ImageDraw.Draw(m2).rounded_rectangle((0, 0, 179, 179), radius=40, fill=255)
        board.paste(big.resize((180, 180), Image.LANCZOS), (100 + i * 380, 390), m2)
    board.save(os.path.join(out, 'icons-board.png'))
    # game assets: loading screen background, logo, happy hero (pixel size, scaled in code)
    S.save_imageset('bloom_splash_bg', bg)
    S.save_imageset('bloom_logo', lg)
    S.save_imageset('bloom_hero_happy', big_eyed_hero())
    print('ok', out)


if __name__ == '__main__':
    main()
