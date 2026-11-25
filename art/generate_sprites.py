#!/usr/bin/env python3
"""Generates DUSTBLOOM stage-0 pixel art.

Every sprite is drawn pixel by pixel from the palette in docs/style-guide.md,
so the art is reproducible and easy to tweak. Output:

  client/Dustbloom/Assets.xcassets/<name>.imageset/<name>.png  (1x pixels)
  art/preview.png                                              (farm mockup, x6)

Run from the repo root:  python3 art/generate_sprites.py
Needs Pillow (pip install pillow).
"""
import json
import os
import random
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "client", "Dustbloom", "Assets.xcassets")
T = 16  # tile size

# ---------------------------------------------------------------- palette
P = {
    "outline": "#2b1d16",
    # wasteland: ash-lilac, makes the living farm pop
    "dust0": "#4f4959", "dust1": "#5f5869", "dust2": "#716a7b",
    "dust3": "#857e8e", "dust4": "#9c95a3", "dust5": "#b8b1bb",
    # living soil
    "soil0": "#2f1c13", "soil1": "#452a1c", "soil2": "#5c3a26",
    "soil3": "#774d32", "soil4": "#91623f",
    # greens
    "g0": "#1c4227", "g1": "#2a6331", "g2": "#3f8a37", "g3": "#69b443", "g4": "#a9de63",
    # gold / wheat
    "y0": "#7d4f10", "y1": "#b97f1a", "y2": "#e8b443", "y3": "#ffe08a", "y4": "#fff4c8",
    # ember pumpkin
    "o0": "#6e2810", "o1": "#a8461a", "o2": "#dd6f26", "o3": "#ff9d43", "o4": "#ffcf8a",
    # moon (rare / magic)
    "m0": "#1b4253", "m1": "#2b7383", "m2": "#55b9b8", "m3": "#9fead9", "m4": "#e9fff6",
    "white": "#fff6e0",
}


def rgba(name, a=255):
    h = P[name].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def new(w=T, h=T):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), rgba(c) if isinstance(c, str) else c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def outline(im, color="outline"):
    """1px outer outline around every opaque pixel (4-neighbourhood)."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and src.getpixel((nx, ny))[3]:
                    put(im, x, y, color)
                    break
    return im


def ellipse(im, cx, cy, rx, ry, shade):
    """Filled ellipse lit from the top-left. shade(level 0..4) -> colour."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0:
                light = -0.55 * dx - 0.75 * dy + 0.35 * (1 - d)
                lvl = 0 if light < -0.45 else 1 if light < -0.05 else 2 if light < 0.35 else 3 if light < 0.7 else 4
                put(im, x, y, shade(lvl))


# ---------------------------------------------------------------- tiles
def tile_dust(seed):
    rnd = random.Random(seed)
    im = new()
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            c = "dust3" if r < 0.84 else "dust2" if r < 0.94 else "dust4"
            put(im, x, y, c)
    # a crack that never touches the edges, so tiles join seamlessly
    x, y = rnd.randint(3, 6), rnd.randint(3, 6)
    for _ in range(rnd.randint(5, 8)):
        put(im, x, y, "dust1")
        put(im, x + 1, y, "dust4") if rnd.random() < 0.4 else None
        x += rnd.choice((1, 1, 0))
        y += rnd.choice((1, 0, 1, -1))
        x, y = min(max(x, 2), 13), min(max(y, 2), 13)
    # pebble
    px, py = rnd.randint(2, 12), rnd.randint(2, 12)
    put(im, px, py, "dust5")
    put(im, px + 1, py, "dust4")
    put(im, px, py + 1, "dust1")
    put(im, px + 1, py + 1, "dust1")
    return im


def tile_soil():
    rnd = random.Random(7)
    im = new()
    rect(im, 0, 0, T - 1, T - 1, "soil2")
    for row in (1, 5, 9, 13):  # furrows: lit ridge, body, shadow
        for x in range(T):
            put(im, x, row, "soil3")
            put(im, x, row + 1, "soil3" if x % 5 else "soil4")
            put(im, x, row + 3, "soil1")
    for _ in range(10):  # clods
        x, y = rnd.randrange(T), rnd.randrange(T)
        put(im, x, y, rnd.choice(("soil4", "soil1", "soil0")))
    return im


# ---------------------------------------------------------------- crops
def mound(im):
    rect(im, 5, 12, 10, 13, "soil1")
    rect(im, 6, 11, 9, 11, "soil3")
    put(im, 7, 10, "soil4")


def seed_stage(seed_col):
    im = new()
    mound(im)
    put(im, 7, 11, seed_col)
    put(im, 8, 11, "outline")
    return outline(im)


def sprout(blade="g3", tip="g4"):
    im = new()
    mound(im)
    for x, y in ((7, 10), (7, 9), (6, 8), (8, 9), (9, 8)):
        put(im, x, y, blade)
    put(im, 5, 7, tip)
    put(im, 10, 7, tip)
    return outline(im)


def wheat(stage):
    im = new()
    stalks = (4, 7, 10, 12) if stage == 3 else (5, 8, 11)
    for i, sx in enumerate(stalks):
        h = (6 if stage == 2 else 10) - (i % 2)
        for y in range(14 - h, 14):
            put(im, sx, y, "g2" if stage == 2 else ("y1" if y > 9 else "y2"))
        top = 14 - h
        if stage == 2:
            put(im, sx + 1, top + 2, "g3")
            put(im, sx - 1, top + 3, "g1")
        else:  # grain heads
            for k in range(4):
                put(im, sx, top - k, "y3" if k % 2 else "y2")
                put(im, sx - 1, top - k + (k % 2), "y2" if k < 3 else "y4")
            put(im, sx + 1, top - 2, "y4")
            put(im, sx, top - 4, "y4")
    return outline(im)


def pumpkin(stage):
    im = new()
    # vine + leaves
    for x in range(3, 13):
        put(im, x, 13, "g1")
    for lx, ly in ((3, 11), (11, 10)):
        rect(im, lx, ly, lx + 2, ly + 1, "g2")
        put(im, lx + 1, ly, "g3")
    if stage == 2:
        ellipse(im, 8, 11.5, 2.6, 2.0, lambda l: ("g0", "g1", "g2", "g3", "g4")[l])
    else:
        ellipse(im, 8, 10, 5.4, 3.9, lambda l: ("o0", "o1", "o2", "o3", "o4")[l])
        for rx in (6, 10):  # ribs
            for y in range(8, 13):
                put(im, rx, y, "o1")
        put(im, 5, 8, "o4")
        rect(im, 7, 5, 8, 6, "g1")  # stem
        put(im, 9, 5, "g2")
    return outline(im)


def turnip(stage):
    im = new()
    lift = 2 if stage == 2 else 0
    # two leaves fanning out from the crown, lit from the top-left
    for i in range(4):
        put(im, 6 - i, 7 - i + lift, "g3" if i < 3 else "g4")
        put(im, 7 - i, 7 - i + lift, "g2")
        put(im, 9 + i, 7 - i + lift, "g2" if i < 3 else "g3")
        put(im, 8 + i, 7 - i + lift, "g1")
    put(im, 7, 8 + lift, "g2")
    put(im, 8, 8 + lift, "g1")
    if stage == 2:
        rect(im, 6, 11, 9, 12, "m1")
        put(im, 6, 11, "m2")
    else:
        ellipse(im, 7.8, 11.0, 3.4, 2.9, lambda l: ("m0", "m1", "m2", "m3", "m4")[l])
        put(im, 7, 14, "m1")
    outline(im)
    if stage == 3:  # moonlight glints outside the outline
        put(im, 13, 9, "m4")
        put(im, 2, 12, "m3")
    return im


# ---------------------------------------------------------------- ui bits
def coin():
    im = new()
    ellipse(im, 8, 8, 5.5, 5.5, lambda l: ("y0", "y1", "y2", "y3", "y4")[l])
    for y in range(6, 11):
        put(im, 8, y, "y1")
    put(im, 7, 6, "y1")
    put(im, 9, 10, "y1")
    return outline(im)


def cursor():
    im = new()
    for a, b in ((0, 0), (12, 0), (0, 12), (12, 12)):
        for i in range(4):
            hx = a + (i if a == 0 else 3 - i)
            vy = b + (i if b == 0 else 3 - i)
            put(im, hx, b if b == 0 else 15, "white")
            put(im, a if a == 0 else 15, vy, "white")
    return im


def sparkle():
    im = new(8, 8)
    for i in range(8):
        put(im, 3, i, "y3" if i in (2, 5) else "y4" if 2 < i < 5 else (0, 0, 0, 0))
        put(im, i, 3, "y3" if i in (2, 5) else "y4" if 2 < i < 5 else (0, 0, 0, 0))
    put(im, 3, 3, "white")
    put(im, 3, 1, "y2")
    put(im, 3, 6, "y2")
    put(im, 1, 3, "y2")
    put(im, 6, 3, "y2")
    return im


# ---------------------------------------------------------------- output
def save_imageset(name, im):
    d = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"))
    contents = {
        "images": [{"filename": name + ".png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)


def write_catalog_root():
    os.makedirs(ASSETS, exist_ok=True)
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)


def write_app_icon(src):
    d = os.path.join(ASSETS, "AppIcon.appiconset")
    os.makedirs(d, exist_ok=True)
    Image.open(src).convert("RGB").resize((1024, 1024), Image.NEAREST).save(os.path.join(d, "AppIcon.png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)


def main():
    write_catalog_root()
    sprites = {
        "tile_dust_0": tile_dust(1),
        "tile_dust_1": tile_dust(2),
        "tile_dust_2": tile_dust(3),
        "tile_soil": tile_soil(),
        "dustwheat_0": seed_stage("y2"),
        "dustwheat_1": sprout(),
        "dustwheat_2": wheat(2),
        "dustwheat_3": wheat(3),
        "emberpumpkin_0": seed_stage("o3"),
        "emberpumpkin_1": sprout("g2", "g3"),
        "emberpumpkin_2": pumpkin(2),
        "emberpumpkin_3": pumpkin(3),
        "moonturnip_0": seed_stage("m3"),
        "moonturnip_1": sprout("m2", "g4"),
        "moonturnip_2": turnip(2),
        "moonturnip_3": turnip(3),
        "ui_coin": coin(),
        "ui_cursor": cursor(),
        "fx_sparkle": sparkle(),
    }
    for name, im in sprites.items():
        save_imageset(name, im)

    logo_dir = os.path.join(ROOT, "art", "source")
    wordmark = os.path.join(logo_dir, "wordmark.png")
    icon = os.path.join(logo_dir, "app_icon_1024.png")
    if os.path.exists(wordmark):
        save_imageset("logo_wordmark", Image.open(wordmark).convert("RGBA"))
    if os.path.exists(icon):
        write_app_icon(icon)

    # preview: a 12x8 slice of the farm, scaled x6
    cols, rows, s = 12, 8, 6
    pv = Image.new("RGBA", (cols * T, rows * T))
    rnd = random.Random(42)
    layout = {
        (4, 3): "dustwheat_3", (5, 3): "dustwheat_3", (6, 3): "dustwheat_2", (7, 3): "dustwheat_1",
        (4, 4): "emberpumpkin_3", (5, 4): "emberpumpkin_2", (6, 4): "emberpumpkin_1", (7, 4): "emberpumpkin_0",
        (4, 5): "moonturnip_3", (5, 5): "moonturnip_2", (6, 5): "moonturnip_1", (7, 5): "dustwheat_0",
    }
    for y in range(rows):
        for x in range(cols):
            tilled = 3 <= x <= 8 and 2 <= y <= 6
            base = sprites["tile_soil"] if tilled else sprites["tile_dust_%d" % rnd.randrange(3)]
            pv.alpha_composite(base, (x * T, y * T))
            if (x, y) in layout:
                pv.alpha_composite(sprites[layout[(x, y)]], (x * T, y * T))
    pv.alpha_composite(sprites["ui_cursor"], (4 * T, 4 * T))
    pv.alpha_composite(sprites["fx_sparkle"], (4 * T + 10, 4 * T - 4))
    pv = pv.resize((pv.width * s, pv.height * s), Image.NEAREST)
    pv.save(os.path.join(ROOT, "art", "preview.png"))

    sheet = Image.new("RGBA", (len(sprites) * (T + 2), T), (0, 0, 0, 0))
    for i, im in enumerate(sprites.values()):
        sheet.alpha_composite(im, (i * (T + 2), 0))
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(os.path.join(ROOT, "art", "sheet.png"))
    print("wrote %d sprites" % len(sprites))


if __name__ == "__main__":
    main()
