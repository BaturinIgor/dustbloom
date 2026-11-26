"""Target look: one phone frame (390x844 pt, rendered @3x) showing where the
game's visuals are heading: a living farm, warm light, a clean HUD with a
labelled dock, side buttons and a seed bubble instead of the fixed crop bar.
Writes /mnt/project-files/stage1/target-frame.png (and art/target.png)."""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

import generate_sprites as G
from generate_sprites import CH, T, build_sprites, ground_name, is_green, life_sources, rgba
from life_art import life_sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "art", "fonts", "PixelifySans.ttf")
W, H = 390, 844       # points
K = 3                 # screen pixels per point
PX = 3                # points per art pixel
U = PX * K            # screen pixels per art pixel


def font(size, weight=700):
    f = ImageFont.truetype(FONT, int(size * K))
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def up(im, scale=U):
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def text(dst, xy, s, size, fill="#fff8e4", stroke="#2a1712", weight=700, anchor="la", sw=None):
    d = ImageDraw.Draw(dst)
    d.text((xy[0] * K, xy[1] * K), s, font=font(size, weight), fill=fill, anchor=anchor,
           stroke_width=int((sw if sw is not None else 2) * K), stroke_fill=stroke)


def pixel_box(dst, x0, y0, x1, y1, fill, top=None, bottom=None, outline="#2a1712", r=2, shadow=True, alpha=255):
    """Rounded pixel-art box in points: outline, lit top band, dark bottom band."""
    d = ImageDraw.Draw(dst)
    o = 1 * PX  # one art pixel
    if shadow:
        sh = Image.new("RGBA", dst.size)
        ImageDraw.Draw(sh).rounded_rectangle([(x0 + 1) * K, (y0 + 4) * K, (x1 + 1) * K, (y1 + 4) * K], r * PX * K,
                                             fill=(20, 10, 24, 110))
        dst.alpha_composite(sh)
    layer = Image.new("RGBA", dst.size)
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], r * PX * K, fill=outline)
    ld.rounded_rectangle([(x0 + o) * K, (y0 + o) * K, (x1 - o) * K, (y1 - o) * K], max(1, (r - 1) * PX * K), fill=fill)
    if bottom:
        ld.rectangle([(x0 + o) * K, (y1 - 3 * o) * K, (x1 - o) * K, (y1 - o) * K], fill=bottom)
    if top:
        ld.rectangle([(x0 + 2 * o) * K, (y0 + o) * K, (x1 - 2 * o) * K, (y0 + 2 * o) * K], fill=top)
    if alpha < 255:
        layer.putalpha(layer.getchannel("A").point(lambda a: a * alpha // 255))
    dst.alpha_composite(layer)


def badge(dst, cx, cy, label):
    w = max(18, 8 + 7 * len(label))
    pixel_box(dst, cx - w / 2, cy - 9, cx + w / 2, cy + 9, "#e23d4a", top="#ff8a8a", bottom="#a81f33", r=3, shadow=False)
    text(dst, (cx, cy - 0.5), label, 12, anchor="mm", sw=1.5)


def world_scene(s):
    fw, fh = 16, 16
    start = (6, 6)
    tilled = [[False] * fw for _ in range(fh)]
    for y in range(6, 10):
        for x in range(5, 10):
            tilled[y][x] = True
    src = life_sources(tilled, start, fw, fh)
    for y in range(4, 12):  # a bigger, older farm: grass reaches further
        for x in range(2, 13):
            src[y][x] = src[y][x] or (x + y) % 3 == 0
    pad = 6
    world = Image.new("RGBA", ((fw + 2 * pad) * T, (fh + 2 * pad) * T))

    def at(tx, ty):
        return (tx + pad) * T, (ty + pad) * T

    for y in range(-pad, fh + pad):
        for x in range(-pad, fw + pad):
            world.alpha_composite(s[ground_name(tilled, src, x, y, fw, fh)], at(x, y))

    objects = []

    def obj(name, tx, ty, tw, th, ox=0, oy=0):
        im = s[name]
        bx, by = at(tx, ty)
        px = bx + (tw * T - im.width) // 2 + ox if name != "prop_house" else bx + ox
        py = by + th * T - im.height + oy
        objects.append((by + th * T + oy, name, px, py))

    sx, sy = start
    for name, dx, dy, tw, th in G.STRUCTURES:
        obj(name + ("_0" if name == "prop_pond" else ""), sx + dx, sy + dy, tw, th)
    obj("prop_manor_1" if "prop_manor_1" in s else "prop_house", sx - 1, sy - 5, 3, 3)
    obj("bld_well_1", sx + 6, sy - 1, 1, 1)
    obj("bld_workshop_1", sx + 6, sy + 1, 2, 2)
    obj("bld_order_board_1", sx - 3, sy + 1, 1, 1)
    obj("prop_scarecrow", sx - 2, sy + 2, 1, 2)
    for x in (sx - 3, sx - 2, sx + 1, sx + 2, sx + 3):
        obj("prop_fence", x, sy - 2, 1, 1, oy=-4)
    obj("prop_stones", sx, sy - 2, 1, 1)
    obj("prop_stones", sx, sy - 1, 1, 1)
    for name, x, y, th in (("prop_dead_tree", 0, 13, 2), ("prop_rock", 14, 12, 1), ("prop_rock", 1, 2, 1)):
        obj(name, x, y - (th - 1), 1, th)

    crops = {}
    rows = ["dustwheat_3", "emberpumpkin_3", "moonturnip_2", "frostcabbage_1"]
    for y in range(6, 10):
        for x in range(5, 10):
            stage = max(0, int(rows[y - 6][-1]) - (1 if (x + y) % 4 == 0 else 0))
            crops[(x, y)] = rows[y - 6][:-1] + str(stage)
    crops.pop((9, 9))  # the empty bed the seed bubble points at
    for (x, y), name in crops.items():
        if name not in s:
            name = "dustwheat_%s" % name[-1]
        bx, by = at(x, y)
        objects.append((by + T - 0.5, name, bx, by + T - CH))

    # life: farmer watering, hens, crow on the scarecrow, butterflies
    fx, fy = at(10, 8)
    objects.append((fy + 22, "unit_farmer_1", fx - 2, fy - 2))
    for i, (hx, hy, fr) in enumerate(((3, 10, 0), (4, 11, 1), (2, 11, 0))):
        px, py = at(hx, hy)
        im = s["life_chicken_%d" % fr]
        if i == 1:
            s["life_chicken_flip"] = im.transpose(Image.FLIP_LEFT_RIGHT)
        objects.append((py + 9, "life_chicken_flip" if i == 1 else "life_chicken_%d" % fr, px + 3, py + 4))
    sc = at(sx - 2, sy + 2)
    objects.append((sc[1] + 40, "life_crow", sc[0] + 9, sc[1] + 4))

    for _, name, px, py in objects:  # baked evening shadows
        key = "shadow_" + name[5:] if name.startswith("prop_") else "shadow_" + name
        if key in s:
            world.alpha_composite(s[key], (px, py))
    for _, name, px, py in sorted(objects, key=lambda o: o[0]):
        world.alpha_composite(s[name], (px, py))
        if name == "prop_windmill":
            world.alpha_composite(s["prop_windmill_sails"].rotate(18, resample=Image.NEAREST), (px - 4, py - 12))
        if name.startswith(("prop_house", "prop_manor")):
            for i, (ox, oy) in enumerate(((35, -6), (38, -13), (42, -21))):
                sm = s["fx_smoke"].copy()
                sm.putalpha(sm.getchannel("A").point(lambda a, i=i: int(a * (1 - i * 0.3))))
                world.alpha_composite(sm, (px + ox, py + oy))
    # water drops from the can
    for i in range(4):
        G.put(world, fx + 16 + i % 2, fy + 18 + i * 2, "m4")
    rnd = random.Random(4)
    for _ in range(6):
        bx, by = at(rnd.randint(3, 12), rnd.randint(3, 11))
        world.alpha_composite(s["life_butterfly_%d" % rnd.randint(0, 1)], (bx + rnd.randint(0, 10), by))
    for (x, y) in ((5, 6), (7, 6), (6, 7), (8, 7)):
        bx, by = at(x, y)
        world.alpha_composite(s["fx_sparkle"], (bx + 9, by - 10))
    return world, at


def grade(img):
    """Warm afternoon grade: lift, warm highlights, soft sun glow top-left,
    a light vignette (not the old heavy one), and gentle bloom."""
    w, h = img.size
    base = img.convert("RGB")
    # bloom: blur the bright parts and add them back
    bright = base.point(lambda v: max(0, v - 150) * 2)
    bloom = bright.filter(ImageFilter.GaussianBlur(10 * K))
    base = ImageChops.add(base, bloom.point(lambda v: v * 0.55))
    # warm sun from top-left
    glow = Image.new("RGB", (w, h))
    gd = glow.load()
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            d = math.hypot(x / w - 0.05, (y / h - 0.0) * 1.2)
            a = max(0.0, 1 - d * 1.25) ** 2
            c = (int(120 * a), int(70 * a), int(20 * a))
            for yy in range(y, min(h, y + 4)):
                for xx in range(x, min(w, x + 4)):
                    gd[xx, yy] = c
    base = ImageChops.add(base, glow)
    # soft vignette
    vig = Image.new("L", (w, h))
    vd = vig.load()
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            d = math.hypot((x / w - 0.5) / 0.5, (y / h - 0.5) / 0.5)
            v = int(255 * min(1, max(0, (d - 0.75) / 0.7)) * 0.55)
            for yy in range(y, min(h, y + 4)):
                for xx in range(x, min(w, x + 4)):
                    vd[xx, yy] = v
    dark = Image.new("RGB", (w, h), (26, 14, 34))
    base = Image.composite(dark, base, vig)
    return base.convert("RGBA")


def hud(screen, s):
    # --- top bar: level shield + XP, resources with +
    top = 58
    sh = up(s["hud_level"])
    screen.alpha_composite(sh, (14 * K, (top - 4) * K))
    text(screen, (14 + 27, top + 24), "12", 22, anchor="mm")
    pixel_box(screen, 64, top + 10, 128, top + 26, "#2a1d33", outline="#140b18", r=2, alpha=210)
    ImageDraw.Draw(screen).rectangle([(67) * K, (top + 13) * K, (67 + 38) * K, (top + 23) * K], fill="#7cc24a")
    ImageDraw.Draw(screen).rectangle([(67) * K, (top + 13) * K, (67 + 38) * K, (top + 15) * K], fill="#b6e46a")
    text(screen, (96, top + 18), "62%", 10, anchor="mm", sw=1.5)
    text(screen, (64, top + 2), "Игорь", 12, anchor="ls", sw=1.5)

    def pill(x0, icon, value, plus_col):
        pixel_box(screen, x0, top + 6, x0 + 100, top + 32, "#2a1d33", outline="#140b18", r=3, alpha=215)
        ic = up(s[icon], 9 if icon == "ui_coin" else 8) if False else s[icon].resize(
            (int(s[icon].width * 2.4 * K), int(s[icon].height * 2.4 * K)), Image.NEAREST)
        screen.alpha_composite(ic, (int((x0 - 8) * K), int((top + 19) * K - ic.height / 2)))
        text(screen, (x0 + 58, top + 19.5), value, 16, anchor="mm")
        pixel_box(screen, x0 + 78, top + 9, x0 + 97, top + 29, plus_col, top="#b6e46a", bottom="#2f7a3e", r=2,
                  shadow=False)
        text(screen, (x0 + 87.5, top + 18.5), "+", 18, anchor="mm", sw=1.5)

    pill(160, "ui_coin", "12 480", "#4c9e3f")
    pill(278, "hud_dew", "350", "#4c9e3f")

    # --- event chip under the top bar
    pixel_box(screen, 16, 104, 196, 130, "#2a1d33", outline="#140b18", r=3, alpha=215)
    ic = s["hud_sickle"].resize((12 * 2 * K, 12 * 2 * K), Image.NEAREST)
    screen.alpha_composite(ic, (20 * K, 105 * K))
    text(screen, (48, 117.5), "Страда: день урожая", 12, anchor="lm", sw=1.5)
    text(screen, (48, 140), "ещё 03:12:44", 11, fill="#ffd08a", anchor="lm", sw=1.5)

    # --- side buttons, right edge
    for i, (icon, label, b) in enumerate((("hud_mail", "Почта", "2"), ("hud_tasks", "Задания", "!"),
                                          ("hud_calendar", "События", None))):
        y = 108 + i * 66
        pixel_box(screen, 330, y, 374, y + 44, "#f8e7bd", top="#fff8e4", bottom="#b98a4c", r=4)
        icn = s[icon].resize((14 * 2 * K, 14 * 2 * K), Image.NEAREST)
        screen.alpha_composite(icn, ((352 - 14) * K, (y + 22 - 14) * K))
        text(screen, (352, y + 54), label, 10, anchor="mm", sw=1.5)
        if b:
            badge(screen, 372, y + 2, b)

    # --- seed bubble over the empty bed
    bx, by = 196, 452
    pixel_box(screen, bx - 96, by - 74, bx + 96, by - 8, "#f8e7bd", top="#fff8e4", bottom="#d9bf88", r=4)
    tri = [(bx - 8) * K, (by - 9) * K, (bx + 8) * K, (by - 9) * K, bx * K, (by + 2) * K]
    ImageDraw.Draw(screen).polygon(tri, fill="#d9bf88", outline="#2a1712")
    for i, (cid, cost) in enumerate((("dustwheat_3", "2"), ("emberpumpkin_3", "8"), ("moonturnip_3", "20"),
                                     ("frostcabbage_3", "35"))):
        cx = bx - 72 + i * 48
        sel = i == 1
        if sel:
            pixel_box(screen, cx - 21, by - 70, cx + 21, by - 13, "#f6c752", top="#ffe590", bottom="#dc9a2c", r=3,
                      shadow=False)
        name = cid if cid in s else "dustwheat_3"
        spr = s[name].crop((0, 6, 16, 22))
        spr = spr.resize((16 * 2 * K, 16 * 2 * K), Image.NEAREST)
        screen.alpha_composite(spr, ((cx - 16) * K, (by - 70) * K))
        coin = s["ui_coin"].resize((10 * K, 10 * K), Image.NEAREST)
        tw = 7 * len(cost)
        x0 = cx - (10 + 2 + tw) / 2
        screen.alpha_composite(coin, (int(x0 * K), int((by - 29) * K)))
        text(screen, (x0 + 12, by - 24), cost, 11, anchor="lm", sw=1.5)

    # --- floating harvest gain
    text(screen, (122, 330), "+22", 20, fill="#ffe590", anchor="mm")
    coin = s["ui_coin"].resize((12 * K, 12 * K), Image.NEAREST)
    screen.alpha_composite(coin, (140 * K, 318 * K))
    screen.alpha_composite(coin, (104 * K, 304 * K))

    # --- dock
    dock_top = 742
    d = ImageDraw.Draw(screen)
    d.rectangle([0, (dock_top - 3) * K, W * K, H * K], fill="#2a1712")
    d.rectangle([0, dock_top * K, W * K, H * K], fill="#5a3420")
    for i, y in enumerate(range(dock_top + 4, H, 14)):  # planks
        d.rectangle([0, y * K, W * K, (y + 1) * K], fill="#4a2a1a")
    d.rectangle([0, dock_top * K, W * K, (dock_top + 2) * K], fill="#c9883e")
    d.rectangle([0, (dock_top + 2) * K, W * K, (dock_top + 3) * K], fill="#7b4a2c")
    slots = [("dock_barn", "Амбар", "3"), ("dock_orders", "Заказы", "2"), ("dock_raids", "Набеги", None),
             ("dock_workshop", "Мастерская", None), ("dock_storage", "Склад", "!")]
    for i, (icon, label, b) in enumerate(slots):
        cx = 39 + i * 78
        if icon == "dock_raids":
            y0 = dock_top - 26
            pixel_box(screen, cx - 36, y0, cx + 36, y0 + 66, "#e2603a", top="#ffb070", bottom="#b8382a", r=5)
            icn = s[icon].resize((22 * 2 * K + 6 * K, 22 * 2 * K + 6 * K), Image.NEAREST)
            screen.alpha_composite(icn, (int((cx - 25) * K), int((y0 + 6) * K)))
            text(screen, (cx, y0 + 80), label, 13, anchor="mm")
            continue
        y0 = dock_top + 10
        pixel_box(screen, cx - 30, y0, cx + 30, y0 + 52, "#f8e7bd", top="#fff8e4", bottom="#b98a4c", r=4)
        icn = s[icon].resize((18 * 2 * K + 3 * K, 18 * 2 * K + 3 * K), Image.NEAREST)
        screen.alpha_composite(icn, (int((cx - 19.5) * K), int((y0 + 5) * K)))
        text(screen, (cx, y0 + 64), label, 12, anchor="mm", sw=1.5)
        if b:
            badge(screen, cx + 27, y0 + 2, b)
    # home indicator
    d.rounded_rectangle([(W / 2 - 67) * K, (H - 9) * K, (W / 2 + 67) * K, (H - 4) * K], 3 * K, fill="#e8d8c0")


def main():
    s = build_sprites()
    s.update(life_sprites())
    world, at = world_scene(s)
    vw, vh = W // PX, H // PX
    cx, cy = at(8, 6)
    cy += 16
    view = world.crop((cx - vw // 2, cy - vh // 2, cx - vw // 2 + vw, cy - vh // 2 + vh))
    screen = grade(up(view))
    hud(screen, s)
    out_dir = "/mnt/project-files/stage1/"
    os.makedirs(out_dir, exist_ok=True)
    screen.convert("RGB").save(os.path.join(ROOT, "art", "target.png"))
    small = screen.convert("RGB").resize((W * 2, H * 2), Image.LANCZOS)
    small.save(os.path.join(out_dir, "target-frame.png"))
    print("ok", screen.size)


if __name__ == "__main__":
    main()
