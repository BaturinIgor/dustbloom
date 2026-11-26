"""Target frame in the app icon's style. Run from art/: python3 -m hd.frame
Writes art/target-hd.png and /mnt/project-files/stage1/target-frame-hd.png"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from . import objects as O
from .draw import cast_shadow, glow, new, put, sparkle
from .ground import draw_dust, draw_field, draw_grass, draw_pond, grass_mask, turf_edges

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ART)
from life_art import life_sprites  # noqa: E402

FONT = os.path.join(ART, "fonts", "Tiny5.ttf")
W, H = 260, 563     # art pixels = 390 x 844 pt at 1.5 pt per pixel
S = 3               # screen pixels per art pixel (@2x)
K = 2               # screen pixels per point


def world():
    im = new(W, H)
    cores = [(12, 112, 250, 446), (26, 446, 160, 476)]
    m = grass_mask(W, H, cores)
    draw_dust(im, m)
    draw_grass(im, m)
    turf_edges(im, m)
    draw_pond(im, 92, 420, 46, 22)
    draw_field(im, 58, 244, 5, 4)
    # stepping stones from the door to the field
    from .draw import ball
    for (x, y) in ((62, 204), (66, 214), (64, 226), (70, 236)):
        ball(im, x, y, 4, 2.6, "stone", lo=0.3, hi=0.95)

    objs = []  # (base_y, sprite, x, y, shadow)

    def add(sp, x, base, shadow=True):
        objs.append((base, sp, x, base - sp.height, shadow))

    add(O.house(), 6, 200)
    add(O.blossom_tree(), 150, 182)
    fence = O.fence(64)
    add(fence, 2, 224)
    add(O.fence(64), 120, 224)
    add(O.scarecrow(), 4, 330)
    add(O.farmer(1), 224, 330)
    for (x, y, f, fl) in ((168, 408, 0, False), (190, 420, 1, True), (150, 428, 1, False), (206, 404, 0, True)):
        add(O.hen(f, fl), x, y)
    add(O.dead_tree(1), 4, 104)
    add(O.dead_tree(4), 214, 548)
    add(O.rock(), 188, 92)
    add(O.rock(), 40, 530)
    add(O.rock(), 236, 478)

    crops = [["w"] * 5, ["p", "p", "p", "p2", "p"], ["t", "t", "s", "t", "s"], ["s", "s", "s", "s", None]]
    for r, row in enumerate(crops):
        for c, k in enumerate(row):
            if k is None:
                continue
            sp = {"w": O.wheat(3, seed=c + r * 7), "p": O.ember_pumpkin(3), "p2": O.ember_pumpkin(2),
                  "t": O.moon_turnip(2), "s": O.sprout()}[k]
            add(sp, 58 + c * 32, 244 + (r + 1) * 32 - 2, shadow=k in ("w", "p"))

    for base, sp, x, y, sh in objs:
        if sh:
            im.alpha_composite(cast_shadow(sp, alpha=95), (x, y))
    for base, sp, x, y, sh in sorted(objs, key=lambda o: o[0]):
        im.alpha_composite(sp, (x, y))

    # chimney smoke
    rnd = random.Random(3)
    for i in range(14):
        cx, cy = 88 + i * 1.6 + math.sin(i) * 2, 92 - i * 4
        r = 2 + i * 0.35
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if math.hypot(x - cx, y - cy) <= r and rnd.random() < 0.9 - i * 0.05:
                    from .draw import mix
                    mix(im, x, y, "#c2b0e0" if x < cx else "#967cbe", 0.5 - i * 0.03)
    # life: butterflies, fireflies, sparkles on ripe crops, water drops
    lf = life_sprites()
    for (x, y, f) in ((120, 150, 0), (200, 300, 1), (30, 380, 0), (240, 250, 1)):
        im.alpha_composite(lf["life_butterfly_%d" % f], (x, y))
    for _ in range(26):
        x, y = rnd.randrange(10, 250), rnd.randrange(100, 470)
        glow(im, x, y, 4, "#fff4a0", 0.8)
        put(im, x, y, "#ffffff")
    for (x, y) in ((70, 236), (134, 240), (102, 270), (166, 268), (200, 238)):
        sparkle(im, x, y, 3)
    for i in range(5):
        put(im, 222 - i, 320 + i * 2, "#a2c8ff")
    return im


def font(pt):
    return ImageFont.truetype(FONT, int(pt * K))


def text(dst, x, y, s, pt, fill="#fff4e8", stroke="#140818", anchor="la", sw=2):
    ImageDraw.Draw(dst).text((x * K, y * K), s, font=font(pt), fill=fill, anchor=anchor,
                             stroke_width=int(sw * K), stroke_fill=stroke)


def panel(dst, x0, y0, x1, y1, fill="#26163a", rim="#f0a02e", hi="#4a2f66", r=8, shadow=True, alpha=235):
    lay = Image.new("RGBA", dst.size)
    d = ImageDraw.Draw(lay)
    if shadow:
        d.rounded_rectangle([x0 * K, (y0 + 3) * K, x1 * K, (y1 + 3) * K], r * K, fill=(10, 4, 16, 140))
    d.rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], r * K, fill="#140818")
    d.rounded_rectangle([(x0 + 1.5) * K, (y0 + 1.5) * K, (x1 - 1.5) * K, (y1 - 1.5) * K], (r - 1) * K, fill=rim)
    d.rounded_rectangle([(x0 + 3) * K, (y0 + 3) * K, (x1 - 3) * K, (y1 - 3) * K], (r - 2) * K, fill=fill)
    d.rounded_rectangle([(x0 + 3) * K, (y0 + 3) * K, (x1 - 3) * K, (y0 + 3 + (y1 - y0) * 0.35) * K], (r - 2) * K,
                        fill=hi)
    if alpha < 255:
        lay.putalpha(lay.getchannel("A").point(lambda a: a * alpha // 255))
    dst.alpha_composite(lay)


def icon(dst, im, cx, cy, size):
    k = size * K / im.width
    big = im.resize((int(im.width * k), int(im.height * k)), Image.NEAREST)
    dst.alpha_composite(big, (int(cx * K - big.width / 2), int(cy * K - big.height / 2)))


def badge(dst, cx, cy, s):
    w = max(16, 8 + 7 * len(s))
    panel(dst, cx - w / 2, cy - 8, cx + w / 2, cy + 8, fill="#d23a44", rim="#ffe6c0", hi="#ff6a5e", r=8,
          shadow=False, alpha=255)
    text(dst, cx, cy, s, 11, anchor="mm", sw=1.5)


def hud(dst):
    lf = life_sprites()
    from generate_sprites import coin
    coin_im = coin()
    top = 56
    # level: round badge with XP ring and name
    panel(dst, 12, top, 56, top + 44, fill="#34204c", rim="#ffce50", hi="#4a2f66", r=22)
    text(dst, 34, top + 22, "12", 20, anchor="mm")
    panel(dst, 52, top + 12, 124, top + 32, fill="#1a0f28", rim="#7a3a18", hi="#1a0f28", r=6, shadow=False)
    ImageDraw.Draw(dst).rounded_rectangle([56 * K, (top + 16) * K, 98 * K, (top + 28) * K], 4 * K, fill="#5ac86a")
    ImageDraw.Draw(dst).rounded_rectangle([56 * K, (top + 16) * K, 98 * K, (top + 20) * K], 3 * K, fill="#a2ec8a")
    text(dst, 90, top + 22, "62%", 10, anchor="mm", sw=1.5)

    def pill(x0, im, value):
        panel(dst, x0, top + 8, x0 + 104, top + 36, fill="#1a0f28", rim="#7a3a18", hi="#26163a", r=14)
        icon(dst, im, x0 + 4, top + 22, 30)
        text(dst, x0 + 52, top + 22, value, 15, anchor="mm")
        panel(dst, x0 + 80, top + 11, x0 + 101, top + 33, fill="#2f9a5a", rim="#a2ec8a", hi="#5ac86a", r=10,
              shadow=False, alpha=255)
        text(dst, x0 + 90.5, top + 21.5, "+", 16, anchor="mm", sw=1.5)

    pill(150, coin_im, "12 480")
    pill(270, lf["hud_dew"], "350")

    # season event chip
    panel(dst, 12, 108, 206, 140, fill="#26163a", rim="#f0a02e", hi="#34204c", r=10)
    icon(dst, lf["hud_sickle"], 30, 124, 22)
    text(dst, 46, 119, "Страда: день урожая", 11, anchor="lm", sw=1.5)
    text(dst, 46, 131, "осталось 03:12:44", 10, fill="#ffce50", anchor="lm", sw=1.5)

    # side buttons
    for i, (ic, label, b) in enumerate((("hud_mail", "Почта", "2"), ("hud_tasks", "Задания", "!"),
                                        ("hud_calendar", "События", None))):
        y = 112 + i * 68
        panel(dst, 326, y, 374, y + 48, fill="#34204c", rim="#f0a02e", hi="#4a2f66", r=12)
        icon(dst, lf[ic], 350, y + 23, 30)
        text(dst, 350, y + 58, label, 10, anchor="mm", sw=1.5)
        if b:
            badge(dst, 372, y + 2, b)

    # seed bubble over the empty bed (bed 4,3 -> art 186+16, 340)
    bx, by = (58 + 4 * 32 + 16) * 1.5, (244 + 3 * 32 + 4) * 1.5
    panel(dst, bx - 150, by - 82, bx + 14, by - 12, fill="#26163a", rim="#ffce50", hi="#34204c", r=12)
    ImageDraw.Draw(dst).polygon([(bx - 10) * K, (by - 13) * K, (bx + 6) * K, (by - 13) * K, (bx) * K, (by - 2) * K],
                                fill="#ffce50", outline="#140818")
    seeds = [(O.wheat(3), "2"), (O.ember_pumpkin(3), "8"), (O.moon_turnip(2), "20"), (O.frost_cabbage(), "35")]
    for i, (sp, cost) in enumerate(seeds):
        cx = bx - 128 + i * 40
        if i == 1:
            panel(dst, cx - 19, by - 76, cx + 19, by - 18, fill="#7a3a18", rim="#ffce50", hi="#b8661e", r=8,
                  shadow=False, alpha=255)
        crop = sp.crop((0, 12, 32, 44))
        icon(dst, crop, cx, by - 56, 34)
        icon(dst, coin_im, cx - 9, by - 28, 10)
        text(dst, cx - 2, by - 28, cost, 11, anchor="lm", sw=1.5)

    # floating gain over the wheat
    text(dst, 130, 352, "+22", 18, fill="#ffe590", anchor="mm")
    icon(dst, coin_im, 152, 352, 14)

    # dock
    dock = 740
    d = ImageDraw.Draw(dst)
    lay = Image.new("RGBA", dst.size)
    ld = ImageDraw.Draw(lay)
    ld.rectangle([0, (dock - 10) * K, 390 * K, dock * K], fill=(20, 8, 24, 90))
    dst.alpha_composite(lay)
    d.rectangle([0, dock * K, 390 * K, 844 * K], fill="#1a0f28")
    d.rectangle([0, dock * K, 390 * K, (dock + 2) * K], fill="#ffce50")
    d.rectangle([0, (dock + 2) * K, 390 * K, (dock + 4) * K], fill="#7a3a18")
    for y in range(dock + 4, 844, 6):
        d.rectangle([0, y * K, 390 * K, (y + 1) * K], fill="#200f30")
    slots = [("dock_barn", "Амбар", "3"), ("dock_orders", "Заказы", "2"), ("dock_raids", "Набеги", None),
             ("dock_workshop", "Мастерская", None), ("dock_storage", "Склад", "!")]
    for i, (ic, label, b) in enumerate(slots):
        cx = 39 + i * 78
        if ic == "dock_raids":
            y0 = dock - 28
            panel(dst, cx - 36, y0, cx + 36, y0 + 68, fill="#b8382a", rim="#ffce50", hi="#e2603a", r=16)
            g = Image.new("RGBA", dst.size)
            icon(g, lf[ic], cx, y0 + 33, 50)
            dst.alpha_composite(g)
            text(dst, cx, y0 + 82, label, 12, anchor="mm", fill="#ffe590")
            continue
        y0 = dock + 12
        panel(dst, cx - 29, y0, cx + 29, y0 + 52, fill="#34204c", rim="#b8661e", hi="#4a2f66", r=12)
        icon(dst, lf[ic], cx, y0 + 26, 40)
        text(dst, cx, y0 + 64, label, 11, anchor="mm", sw=1.5)
        if b:
            badge(dst, cx + 26, y0 + 2, b)
    d.rounded_rectangle([(195 - 67) * K, 835 * K, (195 + 67) * K, 840 * K], 3 * K, fill="#e8d8f0")


def grade(img):
    w, h = img.size
    base = img.convert("RGB")
    bright = base.point(lambda v: max(0, v - 200) * 3)
    base = ImageChops.add(base, bright.filter(ImageFilter.GaussianBlur(6 * K)).point(lambda v: int(v * 0.6)))
    small = Image.new("RGB", (w // 8, h // 8))
    sp = small.load()
    for y in range(small.height):
        for x in range(small.width):
            u, v = x / small.width, y / small.height
            sun = max(0.0, 1 - math.hypot(u + 0.05, v * 0.8 + 0.05) * 1.1) ** 2
            # god rays from the top-left
            ang = math.atan2(v + 0.1, u + 0.1)
            ray = max(0.0, math.sin(ang * 23 + 1.3)) ** 6 * max(0.0, 1 - math.hypot(u, v) * 1.1) * 0.35
            a = sun + ray
            sp[x, y] = (int(95 * a), int(50 * a), int(18 * a))
    base = ImageChops.add(base, small.resize((w, h), Image.BILINEAR))
    # purple dusk in the lower right and a soft vignette
    tint = Image.new("L", (w // 8, h // 8))
    tp = tint.load()
    for y in range(tint.height):
        for x in range(tint.width):
            u, v = x / tint.width, y / tint.height
            d = math.hypot((u - 0.45) / 0.62, (v - 0.45) / 0.62)
            tp[x, y] = int(255 * min(1.0, max(0.0, (d - 0.55) / 0.8)) * 0.7)
    base = Image.composite(Image.new("RGB", (w, h), (30, 14, 46)), base, tint.resize((w, h), Image.BILINEAR))
    return base.convert("RGBA")


def main():
    w = world()
    screen = w.resize((W * S, H * S), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * K, 844 * K))
    canvas.alpha_composite(screen, (0, (844 * K - screen.height) // 2))
    canvas = grade(canvas)
    hud(canvas)
    out = canvas.convert("RGB")
    out.save(os.path.join(ART, "target-hd.png"))
    os.makedirs("/mnt/project-files/stage1/", exist_ok=True)
    out.save("/mnt/project-files/stage1/target-frame-hd.png")
    print("ok", out.size)


if __name__ == "__main__":
    main()
