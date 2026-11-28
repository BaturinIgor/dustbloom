"""DUSTBLOOM (Bloom) game sprites + world layout.

Every sprite is drawn pixel by pixel in code (original art). Ground point of
each prop is the bottom centre with BASE px of padding, so in SpriteKit
anchorPoint = (0.5, BASE / height).

Run from the repo root:  python3 art/bloom/sprites.py [preview.png]
Writes bloom_* imagesets into client/Dustbloom/Assets.xcassets and the world
layout to client/Dustbloom/Core/Bloom/bloom_world.json.
"""
import json
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, 'client', 'Dustbloom', 'Assets.xcassets')
WORLD_JSON = os.path.join(ROOT, 'client', 'Dustbloom', 'Core', 'Bloom', 'bloom_world.json')
T = 16
BASE = 2
CLIFF = 6

C = dict(
    ink="#2b2340",
    water="#4fc4ec", water_d="#3eaee0", water_l="#8fe0f7", foam="#ffffff",
    g0="#5aae3c", g1="#7ccc4a", g1b="#83d24e", g2="#94dc58", g3="#c8f383", gline="#2f6e3a",
    d0="#7a4a2e", d1="#a8653a", d2="#cf8a4c", d3="#eab071",
    # dust (locked land): warm grey-lilac
    u0="#7d7078", u1="#a59a98", u1b="#a99e9b", u2="#b5aaa4", u3="#d3c8bf", uline="#4c4456",
    ud0="#5e5462", ud1="#7a6e7c", ud2="#968a95", ud3="#b0a4ad",
    t0="#6b3f2a", t1="#9c6238", t2="#c4834c",
    l0="#1f6b45", l1="#2f9a4e", l2="#4cbf55", l3="#7fdc5e", l4="#c4f58a",
    p0="#16503f", p1="#227a55", p2="#33a063", p3="#5fc777",
    r0="#5d6680", r1="#8d97ad", r2="#b7c0d1", r3="#e6ebf2", rline="#3a3f57",
    iron="#e0874a", iron_l="#ffb37a", gold="#ffd040", gold_l="#fff2a0", gold_d="#d8962a",
    gem_d="#2a62d4", gem="#47b6ff", gem_l="#aef0ff",
    berry="#e8394f", berry_l="#ff8a9a", berry_d="#a8203a",
    cotton="#ffffff", cotton_d="#dfe6f2",
    cream="#ffc9d8", cream_d="#f394b0", cream_dd="#d0607f", cheek="#ff6f91",
    fire0="#e2462a", fire1="#ff9a2e", fire2="#ffe066",
    brick="#d0603e", brick_l="#f08a5e", brick_d="#8e3a2a",
    bar="#c9ccd6", bar_l="#ffffff", bar_d="#8a8fa3",
    cloth="#7ec8f0", cloth_d="#4c94c8",
    plank="#d99a5a",
    canvas_r="#ef5b5b", canvas_w="#fff4e0",
    white="#ffffff",
)


def hexc(h, a=255):
    h = C.get(h, h).lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def put(self, x, y, c, a=255):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if a >= 255:
            self.px[x, y] = hexc(c)
            return
        r, g, b, oa = self.px[x, y]
        cr, cg, cb, _ = hexc(c)
        if oa == 0:
            self.px[x, y] = (cr, cg, cb, a)
        else:
            k = a / 255
            self.px[x, y] = (round(r + (cr - r) * k), round(g + (cg - g) * k), round(b + (cb - b) * k), max(oa, a))

    def rect(self, x0, y0, x1, y1, c, a=255):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c, a)

    def disc(self, cx, cy, rx, ry, c, a=255):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.put(x, y, c, a)

    def outline(self, c='ink'):
        """1 px outline around every opaque pixel (selective outline colour)."""
        src = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3] > 128:
                            self.px[x, y] = hexc(c)
                            break


SPRITES = {}


def sprite(name, cv):
    SPRITES[name] = cv.im


# ---------------------------------------------------------------- hero
def hero(frame, name='bloom_hero_'):
    """Bloomling: pink bud with a sprout. frame: idle_0/1, run_0..3; back_* = seen from behind."""
    back = frame.startswith('back_')
    frame = frame[5:] if back else frame
    cv = Canvas(16, 24)
    x, y = 8, 24 - BASE - 1
    bob = 0
    lf, rf = 0, 0
    if frame == 'idle_1':
        bob = 1
    if frame.startswith('run'):
        k = int(frame[-1])
        bob = (0, 1, 0, 1)[k]
        lf, rf = ((-1, 0), (0, 0), (0, -1), (0, 0))[k]
    by = y - bob
    # feet
    cv.rect(x - 4, y - 1 + lf, x - 2, y + lf, 'cream_dd')
    cv.rect(x + 2, y - 1 + rf, x + 4, y + rf, 'cream_dd')
    # body
    cv.disc(x, by - 6, 5.6, 5.4, 'cream')
    cv.disc(x + 1.5, by - 4.5, 3.6, 3.2, 'cream')
    for yy in range(int(by - 5), int(by)):
        cv.put(x + 5, yy, 'cream_d'); cv.put(x + 4, yy + 1, 'cream_d')
    cv.rect(x - 3, by - 1, x + 3, by - 1, 'cream_d')
    cv.put(x - 3, by - 9, 'white'); cv.put(x - 2, by - 10, 'white'); cv.put(x - 4, by - 8, 'white')
    if back:
        # walking away: no face, a darker lower half and the sprout's stem in front
        for yy in range(int(by - 4), int(by)):
            for xx in range(x - 4, x + 5):
                if cv.px[xx, yy][3] > 0:
                    cv.put(xx, yy, 'cream_d')
        cv.put(x - 3, by - 9, 'cream'); cv.put(x - 2, by - 10, 'cream')
        cv.put(x + 1, by - 8, 'white'); cv.put(x + 2, by - 9, 'white')
    # face
    if back:
        pass
    elif frame == 'idle_1':
        cv.rect(x - 3, by - 6, x - 2, by - 6, 'ink'); cv.rect(x + 2, by - 6, x + 3, by - 6, 'ink')
    else:
        for ex in (x - 2, x + 2):
            cv.rect(ex, by - 7, ex, by - 6, 'ink'); cv.put(ex, by - 7, 'white')
            cv.put(ex + (1 if ex < x else 1), by - 6, 'ink')
    if not back:
        cv.put(x - 1, by - 4, 'ink'); cv.put(x, by - 3, 'ink'); cv.put(x + 1, by - 4, 'ink')
        cv.put(x - 4, by - 5, 'cheek'); cv.put(x + 4, by - 5, 'cheek')
    # sprout
    cv.rect(x, by - 13, x, by - 11, 'l0')
    cv.disc(x - 2.5, by - 13.5, 2.6, 1.4, 'l2'); cv.put(x - 3, by - 14, 'l3')
    cv.disc(x + 2.5, by - 14.5, 2.6, 1.4, 'l3'); cv.put(x + 2, by - 15, 'l4')
    cv.disc(x, by - 16.5, 1.6, 1.6, 'berry_l'); cv.put(x, by - 17, 'white')
    cv.outline('ink')
    sprite(name + ('back_' if back else '') + frame, cv)


HERO_FRAMES = ('idle_0', 'idle_1', 'run_0', 'run_1', 'run_2', 'run_3', 'back_idle_0', 'back_run_0', 'back_run_1', 'back_run_2', 'back_run_3')


HELPER_COLORS = {
    'pink': ('#ffc9d8', '#f394b0'), 'sun': ('#ffe58a', '#f2b84a'),
    'sky': ('#bfe6ff', '#86c2ef'), 'plum': ('#e2c4ff', '#b48ae6'),
    'gold': ('#ffe14d', '#e0a12a'),   # founder's golden Bloomling
    'mint': ('#c8f5dc', '#8fd9b0'),   # the extra slot bought in the shop
}

# hero skins: body, shade, deep shade, cheek, bud
HERO_SKINS = {
    'mint': ('#c8f5dc', '#8fd9b0', '#5fae86', '#ff8fa8', 'gold'),
    'sky': ('#d2eaff', '#96c6f2', '#6a98cc', '#ff8fb0', '#ffffff'),
    'sun': ('#ffe9a0', '#f5c24e', '#cf9330', '#ff7f6a', 'berry_l'),
    'star': ('#ddd0ff', '#ab95ee', '#7d68c4', '#ff9ad0', 'gold'),
    'rose': ('#ffb8c8', '#f07896', '#c44a6e', '#ff5070', 'berry'),
    'night': ('#8a86c8', '#5e5aa0', '#3e3a78', '#ff9ad0', 'gem_l'),
    'lemon': ('#fff6a8', '#f0dc58', '#c8aa30', '#ff8f70', 'l3'),
    'lilac': ('#ecd2ff', '#c89cf0', '#9a6cc8', '#ff8fc0', '#ffffff'),
    'ocean': ('#a8f0f0', '#5ccad0', '#2e98a4', '#ff8fa0', 'gem'),
    'ember': ('#ffc49a', '#f08a50', '#c45a2e', '#ff5a5a', 'fire2'),
}


def hero_skins():
    for skin, (b, d, dd, ch, bud) in HERO_SKINS.items():
        keep = {k: C[k] for k in ('cream', 'cream_d', 'cream_dd', 'cheek', 'berry_l')}
        C.update(cream=b, cream_d=d, cream_dd=dd, cheek=ch, berry_l=C.get(bud, bud))
        for f in HERO_FRAMES:
            hero(f, 'bloom_hero_%s_' % skin)
        C.update(keep)


def meta_icons():
    cv = Canvas(14, 14)  # event: festive pennant flag
    cv.rect(2, 1, 2, 13, 't1'); cv.put(2, 0, 'gold_l')
    for k in range(9):
        h = 4 - abs(k - 4) // 2
        cv.rect(3 + k, 2 + (4 - h), 3 + k, 2 + 4 + h - 1, 'berry' if k < 5 else 'berry_l')
    cv.rect(3, 4, 11, 5, 'gold')
    cv.put(6, 4, 'gold_l'); cv.put(9, 4, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_event', cv)
    cv = Canvas(14, 14)  # trophy: leaderboards and achievements
    cv.rect(3, 1, 10, 6, 'gold'); cv.rect(4, 7, 9, 7, 'gold'); cv.rect(5, 8, 8, 8, 'gold_d')
    cv.rect(6, 9, 7, 10, 'gold_d'); cv.rect(4, 11, 9, 12, 't1')
    cv.put(1, 2, 'gold'); cv.put(1, 3, 'gold'); cv.put(2, 4, 'gold')
    cv.put(12, 2, 'gold'); cv.put(12, 3, 'gold'); cv.put(11, 4, 'gold')
    cv.rect(4, 2, 5, 5, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_trophy', cv)
    cv = Canvas(14, 14)  # gift box: starter pack
    cv.rect(1, 5, 12, 12, 'berry'); cv.rect(1, 4, 12, 5, 'berry_l')
    cv.rect(6, 4, 7, 12, 'gold'); cv.rect(1, 7, 12, 7, 'gold')
    cv.disc(4.5, 2.5, 2, 1.5, 'gold'); cv.disc(8.5, 2.5, 2, 1.5, 'gold'); cv.put(6, 3, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_gift', cv)
    cv = Canvas(14, 14)  # wardrobe hanger: hero skins
    cv.rect(6, 1, 7, 2, 'r1'); cv.put(8, 1, 'r1')
    for k in range(6):
        cv.put(6 - k, 4 + k // 1 if k < 5 else 8, 'r1'); cv.put(7 + k, 4 + k if k < 5 else 8, 'r1')
    cv.rect(1, 9, 12, 9, 'r1')
    cv.rect(3, 10, 10, 12, 'berry_l'); cv.rect(3, 12, 10, 12, 'berry')
    cv.outline('ink')
    sprite('bloom_ui_skin', cv)
    cv = Canvas(14, 14)  # star medal: event points
    cv.disc(6.5, 6.5, 5.5, 5.5, 'gold_d'); cv.disc(6.5, 6.5, 4.5, 4.5, 'gold')
    for (x, y) in ((6, 3), (7, 3), (4, 6), (9, 6), (6, 5), (7, 5), (5, 8), (8, 8), (6, 7), (7, 7), (5, 6), (8, 6)):
        cv.put(x, y, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_medal', cv)
    cv = Canvas(10, 11)  # padlock: premium reward without the pass
    cv.rect(2, 1, 7, 1, 'r2'); cv.rect(2, 1, 2, 4, 'r2'); cv.rect(7, 1, 7, 4, 'r2')
    cv.rect(1, 5, 8, 10, 'gold'); cv.rect(1, 5, 8, 5, 'gold_l'); cv.rect(4, 7, 5, 8, 'gold_d')
    cv.outline('ink')
    sprite('bloom_ui_lock', cv)


def helper(color, frame):
    """Small Bloomling helper (12x16), same family as the hero."""
    body, shade = HELPER_COLORS[color]
    cv = Canvas(12, 16)
    x, y = 6, 16 - BASE - 1
    bob = 1 if frame in ('idle_1', 'run_1') else 0
    lf = -1 if frame == 'run_0' else 0
    rf = -1 if frame == 'run_1' else 0
    by = y - bob
    cv.rect(x - 3, y + lf, x - 2, y + lf, shade)
    cv.rect(x + 2, y + rf, x + 3, y + rf, shade)
    cv.disc(x, by - 4, 4, 3.8, body)
    for yy in range(by - 4, by):
        cv.put(x + 3, yy, shade)
    cv.rect(x - 2, by - 1, x + 2, by - 1, shade)
    cv.put(x - 2, by - 6, 'white')
    cv.put(x - 1, by - 4, 'ink'); cv.put(x + 1, by - 4, 'ink')
    cv.put(x - 3, by - 3, 'cheek'); cv.put(x + 3, by - 3, 'cheek')
    if color == 'gold':  # a tiny crown instead of the sprout, and a sparkle
        cv.rect(x - 2, by - 8, x + 2, by - 8, 'gold_d')
        for xx in (x - 2, x, x + 2):
            cv.put(xx, by - 9, 'gold')
        cv.put(x, by - 10, 'gold_l'); cv.put(x - 1, by - 8, 'berry')
        cv.put(x - 3, by - 6, 'gold_l') if frame.endswith('0') else cv.put(x + 3, by - 7, 'white')
    else:
        cv.rect(x, by - 9, x, by - 8, 'l0')
        cv.put(x - 1, by - 9, 'l2'); cv.put(x - 2, by - 10, 'l2'); cv.put(x + 1, by - 10, 'l3'); cv.put(x + 2, by - 10, 'l3')
    cv.outline('ink')
    sprite('bloom_helper_%s_%s' % (color, frame), cv)


def chest(open_):
    cv = Canvas(16, 16)
    x, y = 8, 16 - BASE - 1
    cv.rect(x - 6, y - 7, x + 6, y, 't1')
    cv.rect(x - 6, y - 7, x + 6, y - 7, 't2')
    for xx in (x - 6, x + 6):
        cv.rect(xx, y - 7, xx, y, 'gold_d')
    cv.rect(x - 6, y - 3, x + 6, y - 3, 'gold_d')
    if open_:
        cv.rect(x - 5, y - 9, x + 5, y - 8, 'gold')            # treasure glow
        cv.put(x - 3, y - 10, 'gold_l'); cv.put(x + 2, y - 10, 'gold_l'); cv.put(x, y - 11, 'white')
        cv.rect(x - 6, y - 14, x + 6, y - 12, 't1'); cv.rect(x - 6, y - 14, x + 6, y - 14, 't2')
    else:
        cv.rect(x - 6, y - 11, x + 6, y - 8, 't1'); cv.rect(x - 6, y - 11, x + 6, y - 11, 't2')
        cv.rect(x - 6, y - 8, x + 6, y - 8, 'gold_d')
        cv.rect(x - 1, y - 9, x + 1, y - 6, 'gold'); cv.put(x, y - 7, 'ink')
        cv.put(x - 4, y - 10, 'd3')
    cv.outline('ink')
    sprite('bloom_chest_%s' % ('open' if open_ else 'closed'), cv)


def nursery():
    cv = Canvas(22, 24)
    x, y = 11, 24 - BASE - 1
    # flower pots on a little wooden stand with a leaf roof
    cv.rect(x - 9, y - 3, x + 9, y, 't1'); cv.rect(x - 9, y - 3, x + 9, y - 3, 't2')
    for px_ in (x - 6, x, x + 6):
        cv.rect(px_ - 2, y - 7, px_ + 2, y - 4, 'brick'); cv.rect(px_ - 2, y - 7, px_ + 2, y - 7, 'brick_l')
        cv.rect(px_, y - 10, px_, y - 8, 'l1'); cv.put(px_ - 1, y - 10, 'l3'); cv.put(px_ + 1, y - 11, 'l2')
    cv.put(x - 6, y - 12, 'berry_l'); cv.put(x, y - 12, 'gold'); cv.put(x + 6, y - 12, 'water_l')
    cv.rect(x - 9, y - 18, x - 8, y - 4, 't0'); cv.rect(x + 8, y - 18, x + 9, y - 4, 't0')
    for i in range(-10, 11):
        h = 3 - abs(i) // 5
        cv.rect(x + i, y - 19 - h, x + i, y - 17, 'l2' if i % 3 else 'l1')
    cv.rect(x - 10, y - 19, x + 10, y - 19, 'l3')
    cv.outline('ink')
    sprite('bloom_nursery', cv)


def pick(tier):
    """Pickaxe, handle bottom at the canvas bottom centre, head on top."""
    head = [('r1', 'r3'), ('r1', 'r3'), ('bar', 'bar_l'), ('gold', 'gold_l')][tier]
    handle = 't1' if tier < 3 else 'd3'
    cv = Canvas(13, 14)
    for k in range(10):
        cv.put(6, 12 - k, handle)
    cv.put(6, 12, 't0')
    if tier == 0:  # wooden: smaller head
        cv.rect(3, 2, 9, 3, 'd2'); cv.put(2, 4, 'd2'); cv.put(10, 4, 'd2'); cv.rect(4, 2, 8, 2, 'd3')
    else:
        cv.rect(2, 1, 10, 3, head[0]); cv.rect(3, 1, 9, 1, head[1])
        cv.put(1, 3, head[0]); cv.put(1, 4, head[0]); cv.put(11, 3, head[0]); cv.put(11, 4, head[0])
        if tier == 3:
            cv.put(6, 2, 'berry')
    cv.outline('ink')
    sprite('bloom_pick_%d' % tier, cv)


# ---------------------------------------------------------------- props
def tree(kind):
    cv = Canvas(20, 28)
    x, y = 10, 28 - BASE - 1
    cv.rect(x - 1, y - 8, x + 1, y, 't1'); cv.rect(x + 1, y - 8, x + 1, y, 't0'); cv.put(x - 1, y - 8, 't2')
    cv.put(x - 2, y, 't1'); cv.put(x + 2, y, 't0')
    if kind == 'tree':
        cv.disc(x, y - 15, 8.2, 7.6, 'l1')
        cv.disc(x - 1, y - 16, 6.4, 5.4, 'l2')
        cv.disc(x - 2, y - 18, 3.8, 2.8, 'l3')
        for p in ((-4, -19), (-3, -20), (-2, -20)):
            cv.put(x + p[0], y + p[1], 'l4')
        for p in ((4, -11), (5, -14), (-5, -11), (2, -10), (6, -16)):
            cv.put(x + p[0], y + p[1], 'l0')
        for p in ((3, -16), (-3, -13), (5, -19)):
            cv.put(x + p[0], y + p[1], 'berry'); cv.put(x + p[0], y + p[1] - 1, 'berry_l')
        cv.outline('l0')
    else:  # pine
        for i, (w, yy) in enumerate(((8, -9), (6.5, -14), (5, -19), (3, -23))):
            for dx in range(-int(w), int(w) + 1):
                for dy in range(0, 5):
                    if abs(dx) <= w - dy * w / 5:
                        cv.put(x + dx, y + yy - dy, 'p1' if dx > 1 else 'p2')
            cv.rect(x - int(w) + 1, y + yy, x - 1, y + yy, 'p3')
        cv.put(x, y - 27, 'p3')
        cv.outline('p0')
    sprite('bloom_' + kind, cv)


def rock(ore):
    cv = Canvas(18, 16)
    x, y = 9, 16 - BASE - 1
    cv.disc(x, y - 5, 7.5, 5.6, 'r1')
    cv.disc(x - 1, y - 6, 5.2, 3.8, 'r2')
    cv.put(x - 4, y - 8, 'r3'); cv.put(x - 3, y - 8, 'r3'); cv.put(x - 4, y - 7, 'r3'); cv.put(x - 2, y - 9, 'r3')
    cv.rect(x - 6, y - 1, x + 6, y - 1, 'r0'); cv.rect(x + 4, y - 4, x + 6, y - 2, 'r0')
    if ore:
        oc, ol = {'iron': ('iron', 'iron_l'), 'gold': ('gold', 'gold_l')}[ore]
        for (a, b) in ((1, -6), (4, -4), (-3, -3), (2, -9), (-5, -6)):
            cv.put(x + a, y + b, oc); cv.put(x + a + 1, y + b, oc); cv.put(x + a, y + b - 1, ol)
    cv.outline('rline')
    sprite('bloom_rock' + ('_' + ore if ore else ''), cv)


def bush(kind):
    cv = Canvas(16, 14)
    x, y = 8, 14 - BASE - 1
    cv.disc(x, y - 4.5, 6, 4.8, 'l1')
    cv.disc(x - 1, y - 5.5, 4, 3, 'l2')
    cv.put(x - 3, y - 7, 'l3'); cv.put(x - 2, y - 8, 'l3')
    if kind == 'berry':
        for (a, b) in ((-3, -4), (2, -6), (1, -2), (-4, -2), (4, -3), (-1, -7)):
            cv.put(x + a, y + b, 'berry'); cv.put(x + a + 1, y + b, 'berry_d'); cv.put(x + a, y + b - 1, 'berry_l')
    else:  # cotton
        for (a, b) in ((-3, -5), (2, -6), (1, -2), (-4, -2), (4, -3)):
            cv.disc(x + a, y + b, 1.6, 1.4, 'cotton'); cv.put(x + a + 1, y + b + 1, 'cotton_d')
    cv.outline('l0')
    sprite('bloom_bush_' + kind, cv)


def crystal():
    cv = Canvas(14, 18)
    x, y = 7, 18 - BASE - 1
    for (ox, h, w) in ((0, 12, 2.6), (-3, 7, 2), (3, 8, 2)):
        for dy in range(h):
            ww = w if dy < h - 3 else w * (h - dy) / 3
            for dx in range(-int(ww), int(ww) + 1):
                cv.put(x + ox + dx, y - dy, 'cloth' if dx >= 0 else 'water_l')
        cv.put(x + ox - 1, y - h + 3, 'white')
    cv.rect(x - 5, y, x + 5, y, 'r1')
    cv.outline('cloth_d')
    sprite('bloom_crystal', cv)


def cracks():
    for stage, lines in ((1, [((9, 6), (8, 8), (9, 9), (7, 11))]),
                         (2, [((9, 6), (8, 8), (9, 9), (7, 11)), ((4, 8), (6, 9), (5, 11)), ((12, 7), (13, 9), (12, 11), (13, 12))])):
        cv = Canvas(18, 16)
        for pts in lines:
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                n = max(abs(x1 - x0), abs(y1 - y0))
                for k in range(n + 1):
                    cv.put(round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n), 'rline')
        sprite('bloom_crack_%d' % stage, cv)


def cloud_shadow():
    cv = Canvas(72, 34)
    for (cx, cy, rx, ry) in ((24, 18, 20, 12), (44, 14, 22, 12), (56, 20, 14, 9)):
        for y in range(34):
            for x in range(72):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1 and (d < 0.75 or (x + y) % 2 == 0):
                    cv.px[x, y] = (20, 40, 70, 255)
    sprite('bloom_cloud', cv)


def stump(kind):
    cv = Canvas(14, 10)
    x, y = 7, 10 - BASE - 1
    cv.rect(x - 3, y - 3, x + 3, y, 't1'); cv.rect(x + 2, y - 3, x + 3, y, 't0')
    cv.rect(x - 3, y - 4, x + 3, y - 4, 't2'); cv.put(x, y - 4, 'd3'); cv.put(x - 1, y - 4, 'd3')
    cv.put(x - 4, y, 't1'); cv.put(x + 4, y, 't0')
    if kind == 'pine':
        cv.put(x - 2, y - 5, 'p2'); cv.put(x + 2, y - 5, 'p2')
    cv.outline('t0')
    sprite('bloom_stump' + ('_pine' if kind == 'pine' else ''), cv)


def flower(c, name):
    cv = Canvas(5, 7)
    x, y = 2, 7 - BASE - 1
    cv.put(x, y, 'l0'); cv.put(x, y - 1, 'l1')
    cv.put(x, y - 2, c); cv.put(x - 1, y - 3, c); cv.put(x + 1, y - 3, c); cv.put(x, y - 4, c)
    cv.put(x, y - 3, 'gold')
    sprite('bloom_flower_' + name, cv)


def tuft():
    cv = Canvas(5, 5)
    cv.put(2, 1, 'g3'); cv.put(1, 2, 'g2'); cv.put(3, 2, 'g2'); cv.put(0, 2, 'g0'); cv.put(4, 2, 'g0')
    sprite('bloom_tuft', cv)


def shadow():
    cv = Canvas(14, 5)
    cv.disc(7, 2.5, 7, 2.5, 'gline', 90)
    sprite('bloom_shadow', cv)


# ---------------------------------------------------------------- buildings
def furnace(f):
    cv = Canvas(26, 26)
    x, y = 12, 26 - BASE - 1
    cv.rect(x - 7, y - 13, x + 7, y, 'r1')
    cv.rect(x - 7, y - 13, x + 7, y - 12, 'r2')
    for (a, b) in ((-5, -9), (2, -10), (-1, -5), (4, -4), (-6, -3), (5, -8)):
        cv.rect(x + a, y + b, x + a + 1, y + b, 'r0')
    cv.disc(x, y - 4, 4, 4.5, 'ink')
    cv.rect(x - 4, y - 4, x + 4, y - 1, 'ink')
    cv.rect(x - 3, y - 4, x + 3, y - 1, 'fire0')
    fl = [(-2, -5), (0, -7), (2, -5)] if f == 0 else [(-2, -6), (0, -5), (2, -7)]
    for (a, b) in fl:
        cv.rect(x + a, y + b, x + a, y - 1, 'fire1')
    cv.rect(x - 1, y - 3, x + 1, y - 1, 'fire2')
    cv.rect(x + 3, y - 20, x + 5, y - 14, 'r0'); cv.put(x + 3, y - 20, 'r1')
    cv.outline('rline')
    sprite('bloom_furnace_%d' % f, cv)


def anvil():
    cv = Canvas(18, 14)
    x, y = 9, 14 - BASE - 1
    cv.rect(x - 3, y - 2, x + 3, y, 't1'); cv.rect(x - 3, y - 2, x + 3, y - 2, 't2')
    cv.rect(x - 1, y - 5, x + 1, y - 3, 'r0')
    cv.rect(x - 6, y - 8, x + 5, y - 6, 'r1'); cv.rect(x - 6, y - 8, x + 5, y - 8, 'r3')
    cv.put(x - 7, y - 7, 'r1'); cv.put(x - 8, y - 7, 'r1'); cv.put(x + 6, y - 8, 'r1')
    cv.outline('rline')
    sprite('bloom_anvil', cv)


def market():
    cv = Canvas(24, 26)
    x, y = 12, 26 - BASE - 1
    cv.rect(x - 9, y - 6, x + 9, y, 't1'); cv.rect(x - 9, y - 6, x + 9, y - 6, 't2')
    cv.rect(x - 8, y - 14, x - 7, y - 7, 't0'); cv.rect(x + 7, y - 14, x + 8, y - 7, 't0')
    for i in range(-10, 11):
        c = 'canvas_r' if ((i + 10) // 3) % 2 == 0 else 'canvas_w'
        cv.rect(x + i, y - 19, x + i, y - 15, c)
        if (i + 10) % 3 == 1:
            cv.put(x + i, y - 14, c)
    cv.rect(x - 10, y - 19, x + 10, y - 19, 'canvas_w')
    # goods
    cv.disc(x - 5, y - 7, 1.6, 1.4, 'berry'); cv.disc(x - 2, y - 7, 1.6, 1.4, 'gold')
    cv.rect(x + 2, y - 8, x + 6, y - 7, 'plank')
    cv.outline('ink')
    sprite('bloom_market', cv)


def loom():
    cv = Canvas(20, 22)
    x, y = 10, 22 - BASE - 1
    cv.rect(x - 7, y - 14, x - 6, y, 't0'); cv.rect(x + 6, y - 14, x + 7, y, 't0')
    cv.rect(x - 7, y - 15, x + 7, y - 14, 't2')
    cv.rect(x - 5, y - 13, x + 5, y - 5, 'cloth')
    for i in range(-5, 6, 2):
        cv.rect(x + i, y - 13, x + i, y - 5, 'cloth_d')
    cv.rect(x - 7, y - 4, x + 7, y - 3, 't1')
    cv.outline('ink')
    sprite('bloom_loom', cv)


def bridge(vertical):
    if vertical:
        cv = Canvas(T, T + 2)
        for yy in range(0, T + 2):
            c = 'd3' if yy % 4 else 'd1'
            cv.rect(3, yy, T - 4, yy, c)
        cv.rect(2, 0, 2, T + 1, 't0'); cv.rect(T - 3, 0, T - 3, T + 1, 't0')
        sprite('bloom_bridge_v', cv)
    else:
        cv = Canvas(T + 2, T)
        for xx in range(0, T + 2):
            c = 'd3' if xx % 4 else 'd1'
            cv.rect(xx, 4, xx, T - 5, c)
        cv.rect(0, 4, T + 1, 4, 'd2'); cv.rect(0, T - 4, T + 1, T - 4, 't0'); cv.rect(0, T - 3, T + 1, T - 2, 'd0')
        sprite('bloom_bridge_h', cv)


def sign():
    cv = Canvas(22, 16)
    cv.rect(10, 9, 11, 15, 't1')
    cv.rect(1, 1, 20, 9, 'd3'); cv.rect(1, 9, 20, 9, 'd2'); cv.rect(1, 1, 20, 1, 'gold_l')
    cv.outline('ink')
    sprite('bloom_sign', cv)


# ---------------------------------------------------------------- items (12 px icons)
def item(name):
    cv = Canvas(12, 12)
    if name == 'wood':
        cv.rect(1, 4, 10, 8, 't1'); cv.rect(1, 4, 10, 4, 't2'); cv.rect(9, 5, 10, 7, 'd3'); cv.put(10, 6, 't1')
    elif name == 'stone':
        cv.disc(6, 6.5, 4.8, 3.8, 'r1'); cv.disc(5.5, 5.5, 3.2, 2.4, 'r2'); cv.put(4, 4, 'r3'); cv.put(5, 4, 'r3')
    elif name in ('iron_ore', 'gold_ore'):
        oc, ol = ('iron', 'iron_l') if name == 'iron_ore' else ('gold', 'gold_l')
        cv.disc(6, 6.5, 4.8, 3.8, 'r1'); cv.disc(5.5, 5.5, 3.2, 2.4, 'r2')
        for (a, b) in ((4, 5), (7, 7), (6, 4), (3, 8)):
            cv.put(a, b, oc); cv.put(a + 1, b, oc)
        cv.put(6, 3, ol)
    elif name == 'berry':
        for (bx, by) in ((4, 7), (8, 7), (6, 4)):
            cv.disc(bx, by, 2.2, 2.2, 'berry'); cv.put(bx - 1, by - 1, 'berry_l')
        cv.put(6, 1, 'l2'); cv.put(7, 1, 'l3')
    elif name == 'cotton':
        cv.disc(6, 6, 4.2, 3.8, 'cotton'); cv.disc(7, 7, 2.6, 2, 'cotton_d'); cv.put(4, 4, 'white')
    elif name == 'gem':  # dew drop, the premium currency
        cv.disc(6, 7.2, 3.9, 3.6, 'gem_d'); cv.disc(6, 6.8, 3.2, 3, 'gem')
        for k, w in ((1, 0), (2, 0), (3, 1)):
            cv.rect(6 - w, k, 6 + w, k, 'gem_d' if k < 3 else 'gem')
        cv.put(6, 2, 'gem'); cv.rect(4, 5, 4, 7, 'gem_l'); cv.put(5, 4, 'white'); cv.put(8, 9, 'gem_l')
    elif name == 'coin':
        cv.disc(6, 6, 4.4, 4.4, 'gold_d'); cv.disc(6, 5.5, 3.6, 3.6, 'gold'); cv.rect(5, 4, 5, 7, 'gold_l'); cv.put(4, 3, 'white')
    elif name == 'brick':
        cv.rect(1, 5, 10, 9, 'brick'); cv.rect(1, 5, 10, 5, 'brick_l'); cv.rect(1, 9, 10, 9, 'brick_d'); cv.rect(5, 6, 5, 8, 'brick_d')
    elif name in ('iron_bar', 'gold_bar'):
        a, b, c = ('bar', 'bar_l', 'bar_d') if name == 'iron_bar' else ('gold', 'gold_l', 'gold_d')
        for yy in range(4, 10):
            k = (yy - 4)
            cv.rect(3 - k // 3, yy, 8 + k // 3, yy, a)
        cv.rect(3, 4, 8, 4, b); cv.rect(2, 9, 9, 9, c)
    elif name == 'plank':
        cv.rect(1, 3, 10, 5, 'plank'); cv.rect(1, 7, 10, 9, 'plank'); cv.rect(1, 3, 10, 3, 'd3'); cv.rect(1, 7, 10, 7, 'd3')
        cv.rect(1, 5, 10, 5, 'd1'); cv.rect(1, 9, 10, 9, 'd1')
    elif name == 'cloth':
        cv.rect(2, 3, 9, 9, 'cloth'); cv.rect(2, 3, 9, 3, 'water_l')
        for xx in range(3, 9, 2):
            cv.rect(xx, 4, xx, 9, 'cloth_d')
    elif name == 'crystal':
        for dy in range(9):
            w = 2.6 if dy < 6 else 2.6 * (9 - dy) / 3
            for dx in range(-int(w), int(w) + 1):
                cv.put(6 + dx, 10 - dy, 'cloth' if dx >= 0 else 'water_l')
        cv.put(5, 4, 'white')
    elif name == 'flower':
        cv.rect(6, 7, 6, 11, 'l1'); cv.put(5, 9, 'l2'); cv.put(4, 8, 'l2'); cv.put(7, 10, 'l2')
        for (a, b) in ((5, 1), (6, 1), (3, 3), (3, 4), (8, 3), (8, 4), (4, 6), (7, 6), (5, 6), (6, 6), (4, 2), (7, 2), (3, 5), (8, 5)):
            cv.put(a, b, 'berry_l')
        cv.put(4, 2, 'white'); cv.put(5, 1, 'white')
        cv.rect(5, 3, 6, 5, 'gold'); cv.rect(4, 4, 7, 4, 'gold'); cv.put(5, 3, 'gold_l')
    cv.outline('ink')
    sprite('bloom_item_' + name, cv)


FINDS = {
    # bugs (trees and bushes)
    'ladybug': None, 'beetle': None, 'snail': None, 'firefly': None, 'moth': None,
    # fossils (plain rocks)
    'shell': None, 'bone': None, 'amber': None, 'trilobite': None, 'fern': None,
    # gems (ore rocks and crystals)
    'ruby': None, 'sapphire': None, 'emerald': None, 'topaz': None, 'amethyst': None,
}


def find(name):
    cv = Canvas(12, 12)
    gem = {'ruby': ('#e8394f', '#ff8a9a'), 'sapphire': ('#3d7fe0', '#9cc8ff'), 'emerald': ('#2fb36a', '#9af0b8'),
           'topaz': ('#f0a020', '#ffe08a'), 'amethyst': ('#9a5ad8', '#dcb8ff')}
    if name in gem:
        c, l = gem[name]
        widths = [2, 3, 4, 4, 3, 2, 1, 0]
        for dy, w in enumerate(widths):
            cv.rect(6 - w - (0 if w else 0), 2 + dy, 5 + w, 2 + dy, c)
        cv.rect(4, 2, 7, 2, l); cv.rect(3, 3, 5, 3, l); cv.put(4, 3, 'white'); cv.rect(2, 5, 9, 5, l)
    elif name == 'ladybug':
        cv.disc(6, 7, 4, 3.6, 'berry'); cv.rect(6, 4, 6, 10, 'ink'); cv.disc(6, 3.5, 2, 1.4, 'ink')
        for p in ((4, 6), (8, 6), (4, 9), (8, 9)):
            cv.put(*p, 'ink')
        cv.put(4, 5, 'berry_l')
    elif name == 'beetle':
        cv.disc(6, 7, 3.6, 4, '#2f9a8a'); cv.rect(6, 4, 6, 10, '#1f5e55'); cv.disc(6, 2.6, 1.8, 1.4, '#1f5e55')
        cv.put(4, 5, '#9af0e0'); cv.put(2, 6, 'ink'); cv.put(10, 6, 'ink'); cv.put(2, 9, 'ink'); cv.put(10, 9, 'ink')
    elif name == 'snail':
        cv.disc(7, 6, 3.6, 3.6, 'd2'); cv.disc(7, 6, 2, 2, 'd3'); cv.put(7, 6, 'd1')
        cv.rect(1, 9, 10, 10, 'cream'); cv.put(1, 7, 'cream'); cv.put(1, 8, 'cream'); cv.put(2, 6, 'ink')
    elif name == 'firefly':
        cv.disc(6, 6, 4.5, 4.5, 'gold_l', 120); cv.disc(6, 7, 2, 2.6, 'gold'); cv.disc(6, 4, 1.6, 1.4, 'ink')
        cv.put(3, 5, 'water_l'); cv.put(9, 5, 'water_l')
    elif name == 'moth':
        cv.disc(3.6, 4.6, 2.8, 2.8, '#c9a0e8'); cv.disc(8.4, 4.6, 2.8, 2.8, '#c9a0e8')
        cv.disc(4.2, 8.4, 2, 1.8, '#a77fd0'); cv.disc(7.8, 8.4, 2, 1.8, '#a77fd0')
        cv.put(3, 4, 'white'); cv.put(8, 4, 'white'); cv.rect(6, 3, 6, 9, 'ink')
    elif name == 'shell':
        cv.disc(6, 7, 4.8, 4.6, 'cream')
        for k, xx in enumerate((3, 5, 7, 9)):
            cv.rect(xx, 4 if k in (1, 2) else 5, xx, 10, 'd3')
        cv.rect(4, 10, 8, 11, 'd2')
    elif name == 'bone':
        cv.rect(3, 5, 8, 6, 'cream'); cv.disc(2.5, 4.5, 1.6, 1.6, 'cream'); cv.disc(2.5, 6.5, 1.6, 1.6, 'cream')
        cv.disc(9.5, 4.5, 1.6, 1.6, 'cream'); cv.disc(9.5, 6.5, 1.6, 1.6, 'cream')
    elif name == 'amber':
        cv.disc(6, 6, 4.2, 4.4, '#f0a020'); cv.disc(5, 5, 2.4, 2.4, '#ffc860'); cv.put(6, 7, 'ink'); cv.put(7, 7, 'ink'); cv.put(4, 4, 'white')
    elif name == 'trilobite':
        cv.disc(6, 6, 3.6, 4.6, 'r2')
        for yy in (3, 5, 7, 9):
            cv.rect(3, yy, 9, yy, 'r1')
        cv.rect(6, 2, 6, 10, 'r3')
    elif name == 'fern':
        cv.disc(6, 6, 4.8, 4.8, 'r1'); cv.rect(6, 2, 6, 10, 'l1')
        for k in range(3, 10, 2):
            cv.put(5, k, 'l2'); cv.put(4, k - 1, 'l2'); cv.put(7, k, 'l2'); cv.put(8, k - 1, 'l2')
    cv.outline('ink')
    sprite('bloom_find_' + name, cv)


def ui_icons():
    cv = Canvas(14, 14)  # talent tree
    cv.rect(6, 8, 7, 13, 't1'); cv.put(5, 13, 't1'); cv.put(8, 13, 't1')
    cv.disc(6.5, 6, 5.6, 5, 'l1'); cv.disc(5.5, 5, 3.6, 3, 'l2'); cv.put(4, 3, 'l4')
    for p in ((4, 7), (9, 5), (7, 3)):
        cv.put(*p, 'gold')
    cv.outline('ink')
    sprite('bloom_ui_tree', cv)
    cv = Canvas(14, 14)  # album book
    cv.rect(2, 2, 11, 12, 'canvas_r'); cv.rect(2, 2, 3, 12, 'brick_d'); cv.rect(4, 3, 10, 11, 'brick')
    cv.disc(7, 7, 2, 2, 'gold'); cv.put(7, 6, 'gold_l')
    cv.rect(4, 12, 11, 12, 'canvas_w')
    cv.outline('ink')
    sprite('bloom_ui_book', cv)
    cv = Canvas(14, 14)  # shop: a gift box
    cv.rect(2, 6, 11, 12, 'berry'); cv.rect(2, 6, 11, 6, 'berry_l'); cv.rect(1, 4, 12, 6, 'berry_l')
    cv.rect(6, 4, 7, 12, 'gold'); cv.rect(1, 4, 12, 4, 'white')
    cv.put(4, 2, 'gold'); cv.put(5, 3, 'gold'); cv.put(9, 2, 'gold'); cv.put(8, 3, 'gold'); cv.put(3, 3, 'gold_d'); cv.put(10, 3, 'gold_d')
    cv.outline('ink')
    sprite('bloom_ui_shop', cv)
    cv = Canvas(14, 14)  # rewarded ad: a play button in a little screen
    cv.rect(1, 3, 12, 11, 'r0'); cv.rect(2, 4, 11, 10, 'water_l')
    for k in range(3):
        cv.rect(5 + k, 5 + k, 5 + k, 9 - k, 'white')
    cv.rect(4, 12, 9, 12, 'r0')
    cv.outline('ink')
    sprite('bloom_ui_ad', cv)
    cv = Canvas(14, 14)  # dew jar (piggy bank)
    cv.rect(3, 4, 10, 12, 'water_l'); cv.rect(4, 7, 9, 12, 'gem'); cv.rect(4, 7, 9, 7, 'gem_l')
    cv.rect(3, 2, 10, 3, 't1'); cv.rect(3, 2, 10, 2, 't2'); cv.put(5, 9, 'white'); cv.put(8, 10, 'gem_l')
    cv.outline('ink')
    sprite('bloom_ui_jar', cv)
    cv = Canvas(14, 14)  # fertilizer sack
    cv.disc(6.5, 8.5, 5, 4.2, 'd3'); cv.rect(4, 3, 9, 5, 'd3'); cv.rect(4, 5, 9, 5, 'd1'); cv.rect(3, 11, 10, 12, 'd2')
    cv.put(6, 2, 'l2'); cv.put(7, 1, 'l3'); cv.put(5, 1, 'l3')
    cv.disc(6.5, 9, 2, 2, 'l2'); cv.put(6, 8, 'l4')
    cv.outline('ink')
    sprite('bloom_ui_fert', cv)
    cv = Canvas(14, 14)  # season pass: a ribbon medal
    cv.rect(3, 1, 5, 6, 'berry'); cv.rect(8, 1, 10, 6, 'water'); 
    cv.disc(6.5, 9, 4, 4, 'gold_d'); cv.disc(6.5, 8.6, 3.2, 3.2, 'gold'); cv.put(6, 8, 'white'); cv.put(7, 9, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_pass', cv)
    cv = Canvas(9, 8)  # guide arrow that points at the next goal
    for k in range(4):
        cv.rect(1 + k, 3 + k, 7 - k, 3 + k, 'gold' if k else 'gold_l')
    cv.rect(3, 0, 5, 3, 'gold')
    cv.put(3, 0, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_arrow', cv)
    cv = Canvas(14, 14)  # letter: write to the developers
    cv.rect(1, 3, 12, 11, 'canvas_w')
    for k in range(6):
        cv.put(1 + k, 3 + k // 1 if k < 5 else 8, 'd2'); cv.put(12 - k, 3 + k if k < 5 else 8, 'd2')
    cv.rect(1, 11, 12, 11, 'd3')
    cv.disc(6.5, 7.6, 1.6, 1.4, 'berry'); cv.put(6, 7, 'berry_l')
    cv.outline('ink')
    sprite('bloom_ui_mail', cv)
    cv = Canvas(14, 14)  # calendar: daily gifts and quests
    cv.rect(1, 3, 12, 12, 'canvas_w'); cv.rect(1, 3, 12, 5, 'berry'); cv.rect(1, 3, 12, 3, 'berry_l')
    cv.put(4, 1, 'r1'); cv.put(4, 2, 'r1'); cv.put(9, 1, 'r1'); cv.put(9, 2, 'r1')
    for y in (7, 10):
        for x in (3, 6, 9):
            cv.put(x, y, 'u1')
    cv.rect(8, 9, 10, 11, 'gold'); cv.put(9, 10, 'gold_l')
    cv.outline('ink')
    sprite('bloom_ui_calendar', cv)
    cv = Canvas(14, 14)  # new spring: a sprout from a glowing seed
    cv.disc(6.5, 10.5, 4, 2.6, 'd2'); cv.disc(6.5, 10, 3, 1.8, 'd3')
    cv.rect(6, 4, 7, 9, 'l2')
    cv.disc(4, 4, 2.4, 1.6, 'l3'); cv.disc(9, 3, 2.4, 1.6, 'l3'); cv.put(3, 4, 'l4'); cv.put(10, 3, 'l4')
    cv.put(2, 1, 'gold_l'); cv.put(11, 7, 'gold_l'); cv.put(1, 8, 'gold')
    cv.outline('ink')
    sprite('bloom_ui_spring', cv)
    cv = Canvas(14, 14)  # backpack: everything you carry
    cv.rect(2, 4, 11, 12, 't1'); cv.rect(3, 5, 10, 12, 't2'); cv.rect(2, 4, 11, 4, 't2')
    cv.rect(4, 1, 9, 1, 't1'); cv.put(4, 2, 't1'); cv.put(9, 2, 't1'); cv.put(4, 3, 't1'); cv.put(9, 3, 't1')
    cv.rect(3, 5, 10, 7, 'brick'); cv.rect(3, 5, 10, 5, 'brick_l')
    cv.rect(6, 7, 7, 8, 'gold'); cv.put(6, 7, 'gold_l')
    cv.rect(4, 9, 9, 11, 't1'); cv.rect(4, 9, 9, 9, 'brick_l')
    cv.outline('ink')
    sprite('bloom_ui_bag', cv)
    cv = Canvas(14, 14)  # menu: a cog
    import math
    for y in range(14):
        for x in range(14):
            dx, dy = x + 0.5 - 7, y + 0.5 - 7
            r = math.hypot(dx, dy); a = math.atan2(dy, dx)
            tooth = (math.cos(a * 8) > 0.35)
            if r <= 4.6 or (tooth and r <= 6.2):
                cv.put(x, y, 'bar' if dy > 0.5 else 'bar_l')
            if r <= 2.0:
                cv.put(x, y, 'bar_d')
    cv.outline('ink')
    sprite('bloom_ui_menu', cv)
    for f in range(2):  # a little bird for the "flock" happening: wings up / down
        cv = Canvas(11, 7)
        cv.disc(5.5, 3.6, 2.6, 1.7, 'cloth'); cv.put(7, 3, 'white'); cv.put(8, 3, 'gold_d'); cv.put(9, 3, 'gold')
        cv.put(6, 3, 'ink')
        if f == 0:
            cv.rect(2, 1, 4, 1, 'cloth_d'); cv.rect(3, 2, 5, 2, 'cloth'); cv.put(1, 0, 'cloth_d')
        else:
            cv.rect(2, 5, 4, 5, 'cloth_d'); cv.rect(3, 4, 5, 4, 'cloth_d'); cv.put(1, 6, 'cloth_d')
        cv.put(2, 3, 'cloth_d'); cv.put(1, 3, 'cloth_d')
        cv.outline('ink')
        sprite('bloom_fx_bird_%d' % f, cv)
    cv = Canvas(10, 10)  # eternal seed (rebirth currency)
    cv.disc(4.5, 5, 3.6, 4.2, 'gold_d'); cv.disc(4.3, 4.8, 2.8, 3.4, 'gold'); cv.put(3, 3, 'gold_l'); cv.put(3, 4, 'gold_l')
    cv.put(5, 0, 'l3'); cv.put(6, 0, 'l2')
    cv.outline('ink')
    sprite('bloom_item_seed', cv)


def fx():
    cv = Canvas(3, 3); cv.put(1, 0, 'white'); cv.put(0, 1, 'white'); cv.put(1, 1, 'white'); cv.put(2, 1, 'white'); cv.put(1, 2, 'white')
    sprite('bloom_fx_spark', cv)
    cv = Canvas(4, 3); cv.rect(0, 1, 3, 1, 'berry_l'); cv.rect(1, 0, 2, 2, 'berry_l'); cv.put(1, 1, 'white')
    sprite('bloom_fx_petal', cv)
    cv = Canvas(4, 3); cv.rect(0, 1, 3, 1, 'l3'); cv.rect(1, 0, 2, 2, 'l3'); cv.put(1, 1, 'l4')
    sprite('bloom_fx_leaf', cv)
    cv = Canvas(6, 6); cv.disc(3, 3, 3, 3, 'white', 200); cv.disc(3, 3, 1.6, 1.6, 'white')
    sprite('bloom_fx_puff', cv)
    cv = Canvas(3, 3); cv.rect(0, 0, 2, 2, 'r2'); cv.put(0, 0, 'r3')
    sprite('bloom_fx_chip', cv)
    cv = Canvas(5, 4)  # butterfly
    cv.put(0, 0, 'gold'); cv.put(1, 1, 'gold'); cv.put(4, 0, 'gold'); cv.put(3, 1, 'gold'); cv.put(2, 1, 'ink'); cv.put(2, 2, 'ink')
    cv.put(0, 1, 'fire1'); cv.put(4, 1, 'fire1'); cv.put(1, 2, 'gold'); cv.put(3, 2, 'gold')
    sprite('bloom_fx_fly', cv)
    # biome ambience
    cv = Canvas(2, 1); cv.put(0, 0, 'sand_l'); cv.put(1, 0, 'sand')
    sprite('bloom_fx_sand', cv)
    cv = Canvas(3, 3); cv.put(1, 1, 'gem_l'); cv.put(0, 1, 'l4', 140); cv.put(2, 1, 'l4', 140); cv.put(1, 0, 'l4', 140); cv.put(1, 2, 'l4', 140)
    sprite('bloom_fx_spore', cv)
    cv = Canvas(5, 4)  # bee
    cv.put(1, 0, 'white', 200); cv.put(2, 0, 'white', 200)
    cv.rect(0, 1, 3, 2, 'honey'); cv.put(1, 1, 'ink'); cv.put(3, 1, 'ink'); cv.put(4, 2, 'ink'); cv.put(2, 2, 'ink')
    sprite('bloom_fx_bee', cv)
    cv = Canvas(2, 2); cv.put(0, 0, 'u3'); cv.put(1, 0, 'u2'); cv.put(0, 1, 'u2')
    sprite('bloom_fx_ash', cv)
    cv = Canvas(2, 2); cv.put(0, 0, 'fire2'); cv.put(1, 0, 'fire1'); cv.put(0, 1, 'fire1'); cv.put(1, 1, 'fire0')
    sprite('bloom_fx_ember', cv)
    cv = Canvas(5, 5); cv.put(2, 0, 'star_d'); cv.put(2, 4, 'star_d'); cv.put(0, 2, 'star_d'); cv.put(4, 2, 'star_d')
    cv.put(2, 1, 'star'); cv.put(2, 3, 'star'); cv.put(1, 2, 'star'); cv.put(3, 2, 'star'); cv.put(2, 2, 'white')
    sprite('bloom_fx_star', cv)
    cv = Canvas(3, 3); cv.put(1, 1, 'gold_l'); cv.put(0, 1, 'l4', 120); cv.put(2, 1, 'l4', 120); cv.put(1, 0, 'l4', 120); cv.put(1, 2, 'l4', 120)
    sprite('bloom_fx_firefly', cv)


# ---------------------------------------------------------------- 1.0 content: new islands' props, items, buildings
C.update(
    sand="#f2d48a", sand_l="#fff0c2", sand_d="#c9a45a",
    glass="#bdf0ff", glass_d="#74c6e0",
    fish="#ff9f5a", fish_l="#ffd0a0", fish_d="#c8643a",
    mush="#e8463f", mush_l="#ff8f86", stem="#fff1dc", stem_d="#e0cdb0",
    honey="#ffb526", honey_l="#ffe27a", honey_d="#c97a12",
    obs="#3a2f55", obs_l="#6d5aa0", obs_d="#211a33", lava="#ff6a2a",
    star="#fff6b0", star_d="#ffd23f", night="#5a4aa8",
    potion="#c25cff", potion_l="#efb8ff",
)


def dune():
    cv = Canvas(18, 12)
    x, y = 9, 12 - BASE - 1
    cv.disc(x, y - 3, 8, 3.6, 'sand_d'); cv.disc(x - 1, y - 4, 6.4, 2.8, 'sand'); cv.disc(x - 3, y - 5, 3, 1.4, 'sand_l')
    cv.put(x + 3, y - 3, 'sand_l'); cv.put(x + 5, y - 2, 'sand_l')
    cv.put(x - 2, y - 7, 'l2'); cv.put(x - 1, y - 8, 'l3'); cv.put(x - 3, y - 8, 'l3')
    cv.outline('d1')
    sprite('bloom_dune', cv)


def palm():
    cv = Canvas(22, 30)
    x, y = 11, 30 - BASE - 1
    for k in range(16):  # leaning trunk
        cx = x + int(k * 0.25)
        cv.put(cx, y - k, 't1'); cv.put(cx + 1, y - k, 't0' if k % 3 else 't2')
    tx, ty = x + 4, y - 17
    for dx, dy, ln in ((-1, 0, 8), (1, 0, 8), (-1, -1, 6), (1, -1, 6), (0, -1, 4), (-1, 1, 5), (1, 1, 5)):
        for k in range(ln):
            px, py = tx + dx * k, ty + dy * (k // 2) + (k * k) // 14
            cv.put(px, py, 'l2'); cv.put(px, py - 1, 'l3' if k % 2 else 'l1')
    cv.disc(tx, ty + 2, 1.6, 1.4, 't0'); cv.put(tx - 1, ty + 1, 'd2'); cv.put(tx + 1, ty + 2, 'd2')
    cv.outline('l0')
    sprite('bloom_palm', cv)


def pond():
    cv = Canvas(20, 12)
    x, y = 10, 12 - BASE - 1
    cv.disc(x, y - 3, 9, 3.6, 'r1'); cv.disc(x, y - 3, 8, 3, 'water_d'); cv.disc(x - 1, y - 4, 6, 2, 'water')
    cv.rect(x - 4, y - 4, x - 2, y - 4, 'water_l'); cv.rect(x + 2, y - 3, x + 4, y - 3, 'water_l')
    cv.put(x + 2, y - 5, 'fish'); cv.put(x + 3, y - 5, 'fish_l'); cv.put(x + 1, y - 4, 'fish_d')  # a fish fin
    cv.rect(x - 8, y - 7, x - 8, y - 3, 'l1'); cv.put(x - 8, y - 8, 'd1'); cv.rect(x + 8, y - 6, x + 8, y - 3, 'l1'); cv.put(x + 8, y - 7, 'd1')
    cv.outline('gline')
    sprite('bloom_pond', cv)


def mushroom():
    cv = Canvas(16, 14)
    x, y = 8, 14 - BASE - 1
    for (ox, h, r) in ((-3, 4, 3.2), (3, 6, 4), (0, 2, 2.2)):
        cv.rect(x + ox - 1, y - h, x + ox, y, 'stem'); cv.put(x + ox, y - h + 1, 'stem_d')
        cv.disc(x + ox, y - h - 1, r, r * 0.65, 'mush'); cv.put(x + ox - 1, y - h - 2, 'white'); cv.put(x + ox + 1, y - h - 1, 'mush_l')
    cv.outline('ink')
    sprite('bloom_mushroom', cv)


def hive():
    cv = Canvas(16, 18)
    x, y = 8, 18 - BASE - 1
    cv.rect(x - 1, y - 4, x, y, 't1')
    for k, w in enumerate((3, 5, 6, 6, 5, 4, 2)):
        yy = y - 5 - k * 1.6
        cv.rect(x - w, int(yy) - 1, x + w - 1, int(yy), 'honey' if k % 2 else 'honey_d')
    cv.rect(x - 1, y - 9, x, y - 8, 'ink')
    cv.put(x + 5, y - 15, 'ink'); cv.put(x + 6, y - 15, 'gold_l'); cv.put(x - 6, y - 12, 'ink'); cv.put(x - 7, y - 12, 'gold_l')
    cv.outline('d0')
    sprite('bloom_hive', cv)


def obsidian():
    cv = Canvas(18, 16)
    x, y = 9, 16 - BASE - 1
    cv.disc(x, y - 5, 7.5, 5.6, 'obs'); cv.disc(x - 1, y - 6, 5, 3.6, 'obs_l')
    cv.put(x - 3, y - 9, 'white'); cv.put(x - 2, y - 9, 'obs_l')
    for (a, b) in ((3, -3), (4, -4), (5, -4), (-4, -2), (1, -1)):
        cv.put(x + a, y + b, 'lava')
    cv.rect(x - 6, y - 1, x + 6, y - 1, 'obs_d')
    cv.outline('obs_d')
    sprite('bloom_obsidian', cv)


def starstone():
    cv = Canvas(16, 20)
    x, y = 8, 20 - BASE - 1
    cv.disc(x, y - 4, 6, 3.6, 'night'); cv.disc(x - 1, y - 5, 4, 2.4, 'obs_l')
    sx, sy = x, y - 12
    for dx, dy in ((0, -4), (0, -3), (0, 3), (0, 4), (-4, 0), (-3, 0), (3, 0), (4, 0)):
        cv.put(sx + dx, sy + dy, 'star_d')
    cv.disc(sx, sy, 2.2, 2.2, 'star'); cv.put(sx - 1, sy - 1, 'white')
    cv.put(x - 5, y - 8, 'star'); cv.put(x + 5, y - 14, 'star')
    cv.outline('ink')
    sprite('bloom_starstone', cv)


def stump_palm():
    cv = Canvas(14, 10)
    x, y = 7, 10 - BASE - 1
    cv.rect(x - 2, y - 3, x + 2, y, 't1'); cv.rect(x + 1, y - 3, x + 2, y, 't0'); cv.rect(x - 2, y - 4, x + 2, y - 4, 'd3')
    cv.put(x - 3, y, 'sand_d'); cv.put(x + 3, y, 'sand_d')
    cv.outline('t0')
    sprite('bloom_stump_palm', cv)


def item2(name):
    cv = Canvas(12, 12)
    if name == 'sand':
        cv.disc(6, 7.5, 5, 3.2, 'sand_d'); cv.disc(5.5, 7, 3.8, 2.4, 'sand'); cv.put(4, 6, 'sand_l'); cv.put(7, 8, 'sand_l')
    elif name == 'glass':
        cv.rect(3, 2, 8, 10, 'glass'); cv.rect(3, 2, 3, 10, 'glass_d'); cv.rect(4, 1, 7, 1, 'glass_d'); cv.rect(5, 3, 5, 7, 'white')
    elif name == 'fish':
        cv.disc(5.5, 6, 4, 2.6, 'fish'); cv.disc(5, 5, 2.6, 1.2, 'fish_l')
        cv.put(10, 4, 'fish_d'); cv.put(10, 8, 'fish_d'); cv.rect(9, 5, 9, 7, 'fish_d'); cv.put(3, 5, 'ink')
    elif name == 'smoked_fish':
        cv.disc(5.5, 6, 4, 2.6, 'brick_d'); cv.disc(5, 5, 2.6, 1.2, 'brick')
        cv.put(10, 4, 't0'); cv.put(10, 8, 't0'); cv.rect(9, 5, 9, 7, 't0'); cv.put(3, 5, 'ink')
        cv.put(6, 1, 'u3'); cv.put(7, 0, 'u3')
    elif name == 'mushroom':
        cv.rect(5, 6, 6, 10, 'stem'); cv.disc(5.5, 5, 4.4, 2.8, 'mush'); cv.put(4, 4, 'white'); cv.put(7, 3, 'white')
    elif name == 'honey':
        cv.rect(3, 4, 8, 10, 'honey'); cv.rect(3, 4, 8, 4, 'honey_l'); cv.rect(2, 2, 9, 3, 'canvas_r'); cv.put(4, 6, 'honey_l')
    elif name == 'jam':
        cv.rect(3, 4, 8, 10, 'berry'); cv.rect(3, 4, 8, 4, 'berry_l'); cv.rect(2, 2, 9, 3, 'canvas_w'); cv.put(4, 6, 'berry_l')
    elif name == 'elixir':
        cv.rect(5, 1, 6, 3, 'glass_d'); cv.disc(5.5, 7.5, 4, 3.4, 'potion'); cv.disc(5, 7, 2.2, 1.6, 'potion_l'); cv.put(4, 6, 'white')
    elif name == 'obsidian':
        for dy in range(8):
            w = 3.4 if dy < 5 else 3.4 * (8 - dy) / 3
            for dx in range(-int(w), int(w) + 1):
                cv.put(6 + dx, 10 - dy, 'obs_l' if dx < 0 else 'obs')
        cv.put(5, 5, 'white')
    elif name == 'stardust':
        for (a, b) in ((6, 2), (3, 6), (8, 7), (5, 9), (9, 3)):
            cv.put(a, b, 'star'); cv.put(a + 1, b, 'star_d'); cv.put(a, b + 1, 'star_d')
        cv.disc(6, 6, 1.6, 1.6, 'star')
    elif name == 'lantern':
        cv.rect(3, 3, 8, 10, 'glass_d'); cv.rect(4, 4, 7, 9, 'star'); cv.rect(5, 5, 6, 8, 'white')
        cv.rect(3, 2, 8, 2, 'gold_d'); cv.rect(5, 0, 6, 1, 'gold'); cv.rect(3, 11, 8, 11, 'gold_d')
    cv.outline('ink')
    sprite('bloom_item_' + name, cv)


def pick2(tier):
    """Tier 4: crystal pickaxe, tier 5: obsidian pickaxe with a star."""
    cv = Canvas(13, 14)
    for k in range(10):
        cv.put(6, 12 - k, 'd3' if tier == 4 else 'obs_l')
    cv.put(6, 12, 't0')
    a, b = ('cloth', 'water_l') if tier == 4 else ('obs', 'obs_l')
    cv.rect(2, 1, 10, 3, a); cv.rect(3, 1, 9, 1, b)
    cv.put(1, 3, a); cv.put(1, 4, a); cv.put(11, 3, a); cv.put(11, 4, a); cv.put(0, 5, a); cv.put(12, 5, a)
    cv.put(6, 2, 'white' if tier == 4 else 'star')
    cv.outline('ink')
    sprite('bloom_pick_%d' % tier, cv)


def smokehouse():
    cv = Canvas(20, 24)
    x, y = 10, 24 - BASE - 1
    cv.rect(x - 7, y - 10, x + 7, y, 't1')
    for k in range(-7, 8, 3):
        cv.rect(x + k, y - 10, x + k, y, 't0')
    for k in range(6):  # roof
        cv.rect(x - 8 + k, y - 11 - k, x + 8 - k, y - 11 - k, 'brick' if k % 2 else 'brick_d')
    cv.rect(x - 2, y - 6, x + 2, y, 'ink'); cv.rect(x - 1, y - 2, x + 1, y - 1, 'fire1')
    cv.rect(x + 4, y - 19, x + 5, y - 14, 'r1'); cv.put(x + 5, y - 21, 'u3'); cv.put(x + 6, y - 22, 'u3'); cv.put(x + 4, y - 22, 'u2')
    cv.outline('ink')
    sprite('bloom_smokehouse', cv)


def cauldron():
    cv = Canvas(18, 16)
    x, y = 9, 16 - BASE - 1
    cv.put(x - 5, y, 'r0'); cv.put(x + 5, y, 'r0')
    cv.disc(x, y - 4, 6.4, 4.4, 'obs'); cv.disc(x - 1, y - 5, 4.6, 3, 'obs_l')
    cv.rect(x - 6, y - 8, x + 6, y - 8, 'r1'); cv.rect(x - 5, y - 9, x + 5, y - 9, 'potion')
    cv.put(x - 2, y - 11, 'potion_l'); cv.put(x + 2, y - 12, 'potion_l'); cv.put(x, y - 13, 'white')
    cv.put(x - 2, y, 'fire1'); cv.put(x + 1, y, 'fire0'); cv.put(x, y - 1, 'fire2')
    cv.outline('ink')
    sprite('bloom_cauldron', cv)


def observatory():
    cv = Canvas(22, 30)
    x, y = 11, 30 - BASE - 1
    cv.rect(x - 6, y - 14, x + 6, y, 'r1'); cv.rect(x - 6, y - 14, x - 5, y, 'r2'); cv.rect(x + 5, y - 14, x + 6, y, 'r0')
    cv.rect(x - 2, y - 5, x + 2, y, 'ink'); cv.disc(x, y - 6, 2, 1.4, 'ink')
    cv.disc(x, y - 17, 7, 5, 'night'); cv.disc(x - 2, y - 19, 4, 2.6, 'obs_l'); cv.rect(x - 7, y - 15, x + 7, y - 14, 'gold_d')
    for k in range(6):  # telescope
        cv.put(x + 3 + k, y - 20 - k, 'gold'); cv.put(x + 4 + k, y - 20 - k, 'gold_d')
    cv.put(x - 8, y - 26, 'star'); cv.put(x + 1, y - 27, 'star'); cv.put(x - 3, y - 24, 'star_d')
    cv.outline('ink')
    sprite('bloom_observatory', cv)


FINDS2 = ['pearl', 'starfish', 'coral', 'bottle', 'seahorse', 'meteor', 'comet', 'moonstone', 'feather', 'crown']


def find2(name):
    cv = Canvas(12, 12)
    if name == 'pearl':
        cv.disc(6, 7, 4.4, 3.4, 'r2'); cv.disc(6, 5, 4.4, 2.4, 'r3'); cv.disc(6, 7, 2, 2, 'white'); cv.put(5, 6, 'gem_l')
    elif name == 'starfish':
        for dx, dy in ((0, -4), (0, -3), (-4, -1), (-3, -1), (4, -1), (3, -1), (-3, 3), (-2, 2), (3, 3), (2, 2)):
            cv.put(6 + dx, 6 + dy, 'fish')
        cv.disc(6, 6, 2, 2, 'fish'); cv.put(5, 5, 'fish_l')
    elif name == 'coral':
        for (a, b, h) in ((6, 10, 8), (3, 10, 5), (9, 10, 6)):
            cv.rect(a, b - h, a, b, 'berry_l'); cv.put(a - 1, b - h + 1, 'berry_l'); cv.put(a + 1, b - h + 2, 'berry')
    elif name == 'bottle':
        cv.rect(2, 5, 9, 9, 'glass'); cv.rect(10, 6, 11, 8, 'glass_d'); cv.rect(4, 6, 7, 8, 'canvas_w'); cv.put(2, 5, 'white')
    elif name == 'seahorse':
        cv.disc(6, 3, 2, 1.6, 'gold'); cv.rect(6, 4, 7, 8, 'gold'); cv.put(5, 9, 'gold'); cv.put(4, 10, 'gold_d'); cv.put(8, 3, 'gold_d'); cv.put(5, 2, 'ink')
    elif name == 'meteor':
        cv.disc(7, 7, 3.4, 3, 'obs'); cv.put(6, 6, 'lava'); cv.put(8, 8, 'lava')
        for k in range(4):
            cv.put(3 - k // 2, 3 - k // 2 + k % 2, 'fire1')
    elif name == 'comet':
        cv.disc(8, 4, 2.4, 2.4, 'star'); cv.put(7, 3, 'white')
        for k in range(6):
            cv.put(6 - k, 6 + k // 2, 'gem_l' if k % 2 else 'glass')
    elif name == 'moonstone':
        cv.disc(6, 6, 4.4, 4.4, 'r3'); cv.disc(7.5, 5, 3.4, 3.4, 'glass'); cv.put(4, 5, 'white')
    elif name == 'feather':
        for k in range(9):
            cv.put(3 + k // 2 + 1, 10 - k, 'white'); cv.put(2 + k // 2 + 1, 10 - k, 'gem_l' if k > 1 else 'r1')
    elif name == 'crown':
        cv.rect(2, 6, 9, 9, 'gold'); cv.rect(2, 9, 9, 9, 'gold_d')
        for a in (2, 5, 6, 9):
            cv.put(a, 4 if a in (2, 9) else 3, 'gold'); cv.put(a, 5, 'gold')
        cv.put(5, 7, 'berry'); cv.put(3, 7, 'gem'); cv.put(8, 7, 'gem')
    cv.outline('ink')
    sprite('bloom_find_' + name, cv)


def content2():
    dune(); palm(); pond(); mushroom(); hive(); obsidian(); starstone(); stump_palm()
    for n in ('sand', 'glass', 'fish', 'smoked_fish', 'mushroom', 'honey', 'jam', 'elixir', 'obsidian', 'stardust', 'lantern'):
        item2(n)
    pick2(4); pick2(5)
    smokehouse(); cauldron(); observatory()
    for n in FINDS2:
        find2(n)


# ---------------------------------------------------------------- world
# World map, one char per 16 px tile, top row = north. Digits are islands,
# '|' and '=' are bridge spots (one water tile between two islands).
MAP = """
......1111111.................................
....111111111.....5555.....7777777............
...1111111111...5555555...777777777...........
...11111111111=555555555=77777777777..........
....1111111111..55555555..777777777...........
.....11111111....555555....7777777............
.......|..........|...........................
......00000.......222................aaaaa....
......0000000...22222...6666666....aaaaaaaaa..
..4...0000000...222222.666666666...aaaaaaaaa..
.444..0000000=2222222..6666666666=aaaaaaaaaaa.
44444=0000000...222222.666666666...aaaaaaaaa..
44444.0000000...222222=66666666....aaaaaaaaa..
.4444.00000000..222222...............aaaaa....
..444..000000...22222..................|......
...44...0000.....222...................b......
........|..........................bbbbbbbbb..
.....33333333.....................bbbbbbbbbbb.
...333333333333...................bbbbbbbbbbb.
...3333333333333...................bbbbbbbbb..
....33333333333...............................
......333333..................................
........|.....................................
.......88888......9999999.....................
.....888888888...999999999....................
....88888888888=99999999999...................
.....888888888...999999999....................
.......88888......9999999.....................
..............................................
"""

ISLANDS = [
    dict(id=0, name='Луг', price=0,
         spawn={'tree': 5, 'rock': 4, 'bush_berry': 3}, cap=14),
    dict(id=1, name='Сосновый лес', price=15,
         spawn={'pine': 8, 'tree': 2, 'bush_cotton': 3, 'rock': 1}, cap=18),
    dict(id=2, name='Каменный кряж', price=60,
         spawn={'rock': 5, 'rock_iron': 4, 'tree': 1}, cap=14),
    dict(id=3, name='Ягодная поляна', price=140,
         spawn={'bush_berry': 5, 'bush_cotton': 4, 'tree': 2, 'rock': 1}, cap=16),
    dict(id=4, name='Золотая жила', price=280,
         spawn={'rock': 3, 'rock_iron': 3, 'rock_gold': 4}, cap=9),
    dict(id=5, name='Хрустальный холм', price=500,
         spawn={'crystal': 4, 'rock_gold': 2, 'pine': 2, 'rock_iron': 2}, cap=13),
    dict(id=6, name='Песчаная коса', price=800,
         spawn={'dune': 5, 'palm': 4, 'rock': 2}, cap=14),
    dict(id=7, name='Тихая заводь', price=1200,
         spawn={'pond': 4, 'palm': 3, 'bush_berry': 3, 'tree': 2}, cap=15),
    dict(id=8, name='Грибная чаща', price=1800,
         spawn={'mushroom': 6, 'pine': 4, 'bush_cotton': 2}, cap=15),
    dict(id=9, name='Медовый луг', price=2600,
         spawn={'hive': 4, 'tree': 3, 'bush_berry': 3, 'bush_cotton': 2}, cap=15),
    dict(id=10, name='Огненная гора', price=3800,
         spawn={'obsidian': 5, 'rock_gold': 3, 'rock_iron': 3, 'crystal': 1}, cap=15),
    dict(id=11, name='Звёздный пик', price=5500,
         spawn={'starstone': 4, 'crystal': 3, 'obsidian': 2, 'pine': 2}, cap=13),
]
# per-island grass tint so every island reads differently
TINTS = {
    1: dict(g0='#4c9a3a', g1='#6dbd45', g1b='#73c34a', g2='#86cf52', g3='#b9ea7a', gline='#2a6034'),
    2: dict(g0='#6aa844', g1='#8cc957', g1b='#92cd5c', g2='#a3d668', g3='#d2f09a'),
    3: dict(g0='#62b444', g1='#86d353', g1b='#8cd858', g2='#a2e264', g3='#d6f79a'),
    4: dict(g0='#8aa83c', g1='#a9c95a', g1b='#aecd60', g2='#c2dc72', g3='#e6f3a4', gline='#5b6b2a'),
    5: dict(g0='#3f9e7a', g1='#5cc59a', g1b='#62ca9f', g2='#7fd8b0', g3='#bff2da', gline='#245f52'),
    6: dict(g0='#c9a45a', g1='#efd18a', g1b='#f2d590', g2='#f8e2a8', g3='#fff2cc', gline='#8a6a34',
            d0='#8a5a2e', d1='#b88648', d2='#d8a860', d3='#f0c882'),
    7: dict(g0='#3e9a5e', g1='#5abf78', g1b='#60c47e', g2='#7ed494', g3='#b8f0c4', gline='#22603e'),
    8: dict(g0='#5a8a3a', g1='#77a84c', g1b='#7dad52', g2='#93c062', g3='#c4e292', gline='#33522a'),
    9: dict(g0='#8aa93a', g1='#b2cf4e', g1b='#b8d454', g2='#cde06a', g3='#eef5a4', gline='#5a6a24'),
    10: dict(g0='#3a3040', g1='#55485a', g1b='#5a4d60', g2='#6e6074', g3='#9a8aa0', gline='#1e1824',
             d0='#2a1e26', d1='#40303a', d2='#5a404a', d3='#7a5560'),
    11: dict(g0='#4a4a96', g1='#6464b8', g1b='#6a6abd', g2='#8484d0', g3='#c0c0f4', gline='#28285e',
             d0='#2a2a5e', d1='#3e3e80', d2='#5656a0', d3='#7a7ac4'),
}


ISLE_CH = '0123456789ab'


def _parse():
    rows = [r for r in MAP.strip('\n').split('\n')]
    h = len(rows)
    cells = {}
    bridges = []
    for r, row in enumerate(rows):
        for x, ch in enumerate(row):
            y = h - 1 - r
            if ch in ISLE_CH:
                cells.setdefault(ISLE_CH.index(ch), set()).add((x, y))
    def at(x, y):
        r = h - 1 - y
        if 0 <= r < h and 0 <= x < len(rows[r]) and rows[r][x] in ISLE_CH:
            return ISLE_CH.index(rows[r][x])
        return None
    for r, row in enumerate(rows):
        for x, ch in enumerate(row):
            y = h - 1 - r
            if ch == '|':
                bridges.append(dict(tile=(x, y), v=True, a=at(x, y - 1), b=at(x, y + 1)))
            elif ch == '=':
                bridges.append(dict(tile=(x, y), v=False, a=at(x - 1, y), b=at(x + 1, y)))
    for b in bridges:
        assert b['a'] is not None and b['b'] is not None, b
    return cells, bridges


CELLS, BRIDGES = _parse()
for _i in ISLANDS:
    _i['cells'] = CELLS[_i['id']]


def cells_of(isl):
    return set(isl['cells'])


def biome_decor(iid, cv, rnd, inner, mask):
    """Ground detail that makes each late island its own biome."""
    n = len(inner)
    if iid == 6:      # sand spit: wind ripples, shells, dry grass
        for _ in range(n // 30):
            x, y = rnd.choice(inner)
            for k in range(-3, 4):
                if (x + k, y + (k * k) // 6) in mask:
                    cv.put(x + k, y + (k * k) // 6, '#d8b46a')
        for _ in range(n // 160):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#ffffff'); cv.put(x + 1, y, '#ffc9d8'); cv.put(x, y + 1, '#f394b0')
        for _ in range(n // 140):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#8aa84a'); cv.put(x - 1, y - 1, '#a9c95a'); cv.put(x + 1, y - 2, '#8aa84a')
    elif iid == 7:    # backwater: puddles with lily pads and reeds
        for _ in range(n // 260):
            x, y = rnd.choice(inner)
            for a in range(-3, 4):
                for b in range(-1, 2):
                    if abs(a) + abs(b) * 2 <= 3 and (x + a, y + b) in mask:
                        cv.put(x + a, y + b, '#5cb8e6' if b < 1 else '#3c8ec4')
            cv.put(x - 1, y, '#7fd36a'); cv.put(x, y, '#5aa84a')
        for _ in range(n // 120):
            x, y = rnd.choice(inner)
            for k in range(3):
                cv.put(x, y - k, '#4a8a3a')
            cv.put(x, y - 3, '#8a5a2e')
    elif iid == 8:    # mushroom thicket: moss patches, spores, tiny caps
        for _ in range(n // 90):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#4a7a34'); cv.put(x + 1, y, '#4a7a34'); cv.put(x, y + 1, '#3e6a2c')
        for _ in range(n // 150):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#e84a4a'); cv.put(x + 1, y, '#e84a4a'); cv.put(x, y - 0, '#ffffff'); cv.put(x, y + 1, '#f4e2c8')
        for _ in range(n // 120):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#c8f0a0')
    elif iid == 9:    # honey meadow: dense flowers in clumps
        for _ in range(n // 40):
            x, y = rnd.choice(inner)
            c = rnd.choice(('#ffe14d', '#ffffff', '#ff9ad0', '#ffb526'))
            cv.put(x, y, c); cv.put(x + 1, y + 1, '#5a8a2a')
    elif iid == 10:   # fire mountain: glowing lava cracks, ash
        for _ in range(n // 140):
            x, y = rnd.choice(inner)
            for k in range(6):
                x += rnd.choice((-1, 0, 1)); y += 1
                if (x, y) in mask:
                    cv.put(x, y, '#ff6a2a' if k % 3 else '#ffd040')
                    if (x + 1, y) in mask:
                        cv.put(x + 1, y, '#a83a1a')
        for _ in range(n // 70):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#2a2230')
    elif iid == 11:   # star peak: crystal ground with sparkles
        for _ in range(n // 60):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#fff6b0')
        for _ in range(n // 200):
            x, y = rnd.choice(inner)
            for (a, b) in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                cv.put(x + a, y + b, '#ffd23f')
            cv.put(x, y, '#ffffff')
        for _ in range(n // 160):
            x, y = rnd.choice(inner)
            cv.put(x, y, '#a0e0ff'); cv.put(x, y - 1, '#e0f6ff'); cv.put(x + 1, y, '#6ab8e8')


def island_texture(isl, dust):
    """Whole island image (grass top + cliff + foam). Returns image and the
    world position (art px, y up) of its bottom-left corner."""
    cells = cells_of(isl)
    xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    pad = 2
    w = (maxx - minx + 1) * T + pad * 2
    h = (maxy - miny + 1) * T + pad * 2 + CLIFF + 2
    cv = Canvas(w, h)
    rnd = random.Random(isl['id'] * 7 + (1 if dust else 0))
    # image coords: x right, y down. tile (cx, cy) top-left pixel:
    def tl(cx, cy):
        return pad + (cx - minx) * T, pad + (maxy - cy) * T
    mask = set()
    for (cx, cy) in cells:
        ox, oy = tl(cx, cy)
        for yy in range(T):
            for xx in range(T):
                mask.add((ox + xx, oy + yy))
    # round outer corners
    for (cx, cy) in cells:
        ox, oy = tl(cx, cy)
        for (dx, dy, sx, sy) in ((0, 0, -1, 1), (T - 1, 0, 1, 1), (0, T - 1, -1, -1), (T - 1, T - 1, 1, -1)):
            # sx: neighbour x step, sy: neighbour y step in tile coords (y up)
            if (cx + sx, cy) not in cells and (cx, cy + sy) not in cells:
                x0, y0 = ox + dx, oy + dy
                px_s = -1 if dx == 0 else 1
                py_s = -1 if dy == 0 else 1
                for k in range(3):
                    for j in range(3 - k):
                        mask.discard((x0 - px_s * k, y0 - py_s * j))
    tint = TINTS.get(isl['id'], {})
    P = (lambda k: {'g0': 'u0', 'g1': 'u1', 'g1b': 'u1b', 'g2': 'u2', 'g3': 'u3', 'gline': 'uline',
                    'd0': 'ud0', 'd1': 'ud1', 'd2': 'ud2', 'd3': 'ud3'}.get(k, k)) if dust else (lambda k: tint.get(k, k))
    # foam ring under the cliff
    for (x, y) in mask:
        for (dx, dy) in ((1, 0), (-1, 0), (0, -1)):
            q = (x + dx, y + dy)
            if q not in mask:
                cv.put(*q, 'foam', 200)
        if (x, y + 1) not in mask:
            cv.put(x, y + CLIFF + 2, 'foam', 200)
            cv.put(x - 1, y + CLIFF + 2, 'foam', 200); cv.put(x + 1, y + CLIFF + 2, 'foam', 200)
    # cliff: earth band under the grass, then layered rock with stones and cracks
    bottom = sorted((x, y) for (x, y) in mask if (x, y + 1) not in mask)
    for (x, y) in bottom:
        crack = (x * 7 + y * 3) % 11 == 0
        for k in range(1, CLIFF + 1):
            if k <= 2:
                c = 'd2'
            elif k <= 4:
                c = 'd1' if (x + k) % 9 else 'd2'
            else:
                c = 'd0'
            if crack and 2 <= k <= CLIFF:
                c = 'd0'
            cv.put(x, y + k, P(c))
        # stones in the rock
        h = (x * 13 + y * 5) % 17
        if h == 0:
            cv.put(x, y + 3, P('d3')); cv.put(x + 1, y + 3, P('d2')); cv.put(x, y + 4, P('d2'))
        elif h == 7:
            cv.put(x, y + 5, P('d2'))
        cv.put(x, y + CLIFF + 1, 'water_d' if not dust else 'ud0')
    # top: two greens dithered at their border, light from the top-left
    def tone(x, y):
        n = math.sin(x * 0.21 + y * 0.13 + isl['id']) + math.sin(x * 0.11 - y * 0.27) * 1.2
        return n
    for (x, y) in mask:
        n = tone(x, y)
        if n > 1.05:
            c = 'g2'
        elif n > 0.75:
            c = 'g2' if (x + y) % 2 == 0 else 'g1'
        else:
            c = 'g1'
            if (x // 8 + y // 8) % 2 == 0:
                c = 'g1b'
        cv.put(x, y, P(c))
    for (x, y) in mask:
        top = (x, y - 1) not in mask
        left = (x - 1, y) not in mask
        right = (x + 1, y) not in mask
        bot = (x, y + 1) not in mask
        if top:
            cv.put(x, y - 1, P('gline')); cv.put(x, y, P('g3'))
            if (x, y + 1) in mask:
                cv.put(x, y + 1, P('g2'))
        if left:
            cv.put(x - 1, y, P('gline')); cv.put(x, y, P('g3'))
        if right:
            cv.put(x + 1, y, P('gline')); cv.put(x, y, P('g0'))
        if bot and not left:
            cv.put(x, y, P('g0'))
    # grass hanging over the cliff edge
    for (x, y) in bottom:
        ln = (0, 1, 2, 1, 0, 0, 3, 1, 0, 2, 0, 1)[(x * 5 + y) % 12]
        for k in range(1, ln + 1):
            cv.put(x, y + k, P('g0' if k == ln else 'g1'))
    pts = sorted(mask)
    inner = [(x, y) for (x, y) in pts if all((x + a, y + b) in mask for a in (-2, 2) for b in (-2, 2))]
    # grass blades and tufts
    for _ in range(len(cells) * 7):
        (x, y) = rnd.choice(inner)
        if dust:
            cv.put(x, y, P('g0')); cv.put(x + 1, y, P('g0')); cv.put(x + 1, y + 1, P('g0'))
        elif rnd.random() < 0.55:
            cv.put(x, y, P('g0')); cv.put(x, y - 1, P('g0')); cv.put(x + 2, y, P('g0')); cv.put(x + 2, y - 1, P('g3'))
        else:
            cv.put(x, y, P('g3')); cv.put(x - 1, y + 1, P('g2')); cv.put(x + 1, y + 1, P('g2'))
    if not dust:
        for _ in range(len(cells)):
            (x, y) = rnd.choice(inner)
            c = rnd.choice(('white', 'berry_l', 'gold', 'water_l'))
            cv.put(x, y, c); cv.put(x, y + 1, P('g0'))
    else:
        for _ in range(len(cells)):
            (x, y) = rnd.choice(inner)
            cv.put(x, y, 'ud1'); cv.put(x - 1, y - 1, 'ud1'); cv.put(x + 1, y - 2, 'ud1'); cv.put(x, y - 1, 'ud0')
        for _ in range(len(cells)):  # dead twigs and pebbles
            (x, y) = rnd.choice(inner)
            cv.put(x, y, 'ud0'); cv.put(x + 1, y - 1, 'ud0'); cv.put(x - 1, y - 1, 'ud0')
    if not dust:
        biome_decor(isl['id'], cv, rnd, inner, mask)
    # world position of the image's bottom-left corner (y up)
    wx = minx * T - pad
    wy = miny * T - pad - CLIFF - 2
    return cv.im, (wx, wy)


def build_all():
    for f in HERO_FRAMES:
        hero(f)
    for t in range(4):
        pick(t)
    tree('tree'); tree('pine')
    rock(None); rock('iron'); rock('gold')
    bush('berry'); bush('cotton'); crystal()
    for c, n in (('#ffffff', 'white'), ('berry_l', 'pink'), ('gold', 'yellow'), ('water_l', 'blue')):
        flower(c, n)
    tuft(); shadow(); cloud_shadow(); cracks(); stump('tree'); stump('pine')
    furnace(0); furnace(1); anvil(); market(); loom(); nursery(); chest(False); chest(True)
    for c in HELPER_COLORS:
        for f in ('idle_0', 'idle_1', 'run_0', 'run_1'):
            helper(c, f)
    bridge(True); bridge(False); sign()
    for n in ('wood', 'stone', 'iron_ore', 'gold_ore', 'berry', 'cotton', 'coin', 'brick', 'iron_bar', 'gold_bar',
              'plank', 'cloth', 'crystal', 'flower', 'gem'):
        item(n)
    fx()
    for n in FINDS:
        find(n)
    ui_icons()
    content2()
    hero_skins()
    meta_icons()
    tools2()
    foes()
    dungeons()
    folk()
    world = dict(tile=T, islands=[], bridges=[])
    for isl in ISLANDS:
        for dust in (False, True):
            im, pos = island_texture(isl, dust)
            sprite('bloom_isl_%d%s' % (isl['id'], '_dust' if dust else ''), type('X', (), {'im': im})())
        world['islands'].append(dict(id=isl['id'], name=isl['name'], price=isl['price'],
                                     cells=sorted([list(c) for c in cells_of(isl)]),
                                     origin=list(pos), spawn=isl['spawn'], cap=isl['cap']))
    for b in BRIDGES:
        world['bridges'].append(dict(tile=list(b['tile']), vertical=b['v'], a=b['a'], b=b['b']))
    return world


def save_imageset(name, im):
    d = os.path.join(ASSETS, name + '.imageset')
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + '.png'))
    with open(os.path.join(d, 'Contents.json'), 'w') as f:
        json.dump({'images': [{'filename': name + '.png', 'idiom': 'universal'}],
                   'info': {'author': 'xcode', 'version': 1}}, f, indent=2)


def preview(world, path):
    """Rough world preview (all islands, half dust) at x4."""
    S = 4
    minx = min(i['origin'][0] for i in world['islands']) - 20
    maxx = max(i['origin'][0] + SPRITES['bloom_isl_%d' % i['id']].width for i in world['islands']) + 20
    miny = min(i['origin'][1] for i in world['islands']) - 20
    maxy = max(i['origin'][1] + SPRITES['bloom_isl_%d' % i['id']].height for i in world['islands']) + 20
    W, H = maxx - minx, maxy - miny
    im = Image.new('RGBA', (W, H), hexc('water'))
    def paste(name, wx, wy, anchor_bottom=True):
        s = SPRITES[name]
        x = int(wx - minx - (s.width // 2 if anchor_bottom else 0))
        y = int(H - (wy - miny) - s.height + (BASE if anchor_bottom else 0))
        im.alpha_composite(s, (x, y))
    for i in world['islands']:
        paste('bloom_isl_%d%s' % (i['id'], '_dust' if i['id'] in (4, 5) else ''), i['origin'][0], i['origin'][1], False)
    for b in world['bridges']:
        tx, ty = b['tile']
        paste('bloom_bridge_v' if b['vertical'] else 'bloom_bridge_h', tx * T, ty * T, False)
    rnd = random.Random(1)
    objs = []
    for i in world['islands'][:4]:
        cells = [tuple(c) for c in i['cells']]
        rnd.shuffle(cells)
        kinds = [k for k, n in i['spawn'].items() for _ in range(n)]
        for c, k in zip(cells, kinds):
            objs.append((k, c[0] * T + 8, c[1] * T + 4))
    objs.append(('hero_idle_0', 9 * T + 8, 10 * T + 6))
    objs.append(('furnace_0', 11 * T + 8, 10 * T + 4))
    objs.append(('market', 7 * T + 8, 12 * T + 4))
    objs.sort(key=lambda o: -o[2])
    for k, x, y in objs:
        paste('bloom_shadow', x, y - 3)
        paste('bloom_' + k, x, y)
    im.resize((W * S, H * S), Image.NEAREST).save(path)


# ---------------------------------------------------------------- tools 2: axes, shovel, dig spot
def axe(tier):
    """Axe 1 stone, 2 iron, 3 gold, 4 crystal. Same 13x14 frame as the picks (handle at the bottom centre)."""
    a, b = [None, ('r1', 'r3'), ('bar', 'bar_l'), ('gold', 'gold_l'), ('cloth', 'water_l')][tier]
    cv = Canvas(13, 14)
    for k in range(11):
        cv.put(6, 12 - k, 't1' if tier < 3 else 'd3')
    cv.put(6, 12, 't0')
    cv.rect(7, 1, 10, 5, a); cv.rect(11, 2, 11, 6, a); cv.put(11, 1, a)
    cv.rect(8, 1, 10, 1, b); cv.rect(11, 2, 11, 3, b)
    cv.rect(4, 2, 5, 3, a)
    if tier == 4:
        cv.put(9, 3, 'white')
    cv.outline('ink')
    sprite('bloom_axe_%d' % tier, cv)


def shovel():
    cv = Canvas(13, 14)
    for k in range(8):
        cv.put(6, 12 - k, 't1')
    cv.rect(5, 12, 7, 12, 't0')
    cv.rect(4, 1, 8, 4, 'bar'); cv.rect(5, 0, 7, 0, 'bar'); cv.rect(5, 1, 7, 1, 'bar_l'); cv.put(4, 4, 'bar_d'); cv.put(8, 4, 'bar_d')
    cv.outline('ink')
    sprite('bloom_shovel', cv)


def dig_spot():
    """A soft mound with a cross: something is buried here."""
    cv = Canvas(16, 10)
    cv.disc(8, 6, 6.5, 3.2, 'd2'); cv.disc(8, 5.5, 5, 2.4, 'd3'); cv.put(5, 4, 'd4') if 'd4' in C else None
    for k in range(-2, 3):
        cv.put(8 + k, 5 + k, 'brick_d'); cv.put(8 + k, 5 - k, 'brick_d')
    cv.put(3, 2, 'gold_l'); cv.put(13, 3, 'gold_l')
    cv.outline('ink')
    sprite('bloom_dig', cv)


def tools2():
    for t in range(1, 5):
        axe(t)
    shovel(); dig_spot()


# ---------------------------------------------------------------- foes: dust creatures that roam the islands
def foe_slime(f):
    """Dust slime: a squishy blob of grey dust with a sprout of mould. f 0/1 = squash/stretch."""
    cv = Canvas(14, 12)
    h = 4.2 if f == 0 else 4.8
    w = 6.0 if f == 0 else 5.4
    cv.disc(7, 11 - h * 0.85, w + 0.6, h * 0.85, 'sand_d'); cv.disc(6.2, 10.6 - h * 0.85, w * 0.65, h * 0.5, 'sand')
    cv.put(4, int(11 - h * 1.4), 'sand_l'); cv.put(5, int(11 - h * 1.5), 'sand_l')
    cv.rect(2, 10, 12, 10, 'd2')
    ey = int(11 - h)
    cv.rect(4, ey, 5, ey + 1, 'ink'); cv.rect(8, ey, 9, ey + 1, 'ink'); cv.put(4, ey, 'white'); cv.put(8, ey, 'white')
    cv.put(6, ey + 2, 'ink'); cv.put(7, ey + 2, 'ink')
    cv.put(9, int(11 - 2 * h), 'l2'); cv.put(10, int(11 - 2 * h) - 1, 'l3')
    cv.outline('ink')
    sprite('bloom_foe_slime_%d' % f, cv)


def foe_beetle(f):
    """Thorn beetle: a round shell with thorns, little legs alternate."""
    cv = Canvas(15, 12)
    cv.disc(7.5, 6.5, 6, 4.2, 'brick_d'); cv.disc(7, 5.6, 4.6, 3, 'brick'); cv.put(5, 4, 'brick_l'); cv.put(6, 4, 'brick_l')
    cv.rect(7, 3, 7, 9, 'brick_d')
    for x in (3, 7, 11):
        cv.put(x, 2, 'l1'); cv.put(x, 1, 'l3')
    cv.disc(13, 7.5, 1.8, 1.6, 'ink'); cv.put(13, 7, 'white')
    legs = (2, 6, 10) if f == 0 else (4, 8, 12)
    for x in legs:
        cv.put(x, 11, 'ink'); cv.put(x, 10, 'ink')
    cv.outline('ink')
    sprite('bloom_foe_beetle_%d' % f, cv)


def foe_bat(f):
    """Ash bat: flies at night and on the fire mountain."""
    cv = Canvas(16, 11)
    cv.disc(8, 6, 3, 3, 'obs_l'); cv.put(7, 5, 'fire1'); cv.put(9, 5, 'fire1')
    cv.put(6, 2, 'obs_l'); cv.put(10, 2, 'obs_l')
    if f == 0:
        for k in range(5):
            cv.rect(1 + k, 3 + k // 2, 1 + k, 6, 'obs'); cv.rect(14 - k, 3 + k // 2, 14 - k, 6, 'obs')
    else:
        for k in range(5):
            cv.rect(1 + k, 6, 1 + k, 9 - k // 2, 'obs'); cv.rect(14 - k, 6, 14 - k, 9 - k // 2, 'obs')
    cv.put(8, 8, 'white')
    cv.outline('ink')
    sprite('bloom_foe_bat_%d' % f, cv)


def foe_toad(f):
    """Bog toad: hops; f 1 = mid-hop."""
    cv = Canvas(14, 13)
    y = 12 if f == 0 else 10
    cv.disc(7, y - 4, 5.6, 3.8, 'l1'); cv.disc(7, y - 3, 4, 2.4, 'l3')
    cv.disc(4, y - 8, 1.8, 1.8, 'l1'); cv.disc(10, y - 8, 1.8, 1.8, 'l1')
    cv.put(4, y - 8, 'ink'); cv.put(10, y - 8, 'ink'); cv.put(4, y - 9, 'white'); cv.put(10, y - 9, 'white')
    cv.rect(5, y - 4, 9, y - 4, 'l0')
    cv.put(3, y - 5, 'berry'); cv.put(11, y - 6, 'berry')
    if f == 1:
        cv.rect(2, y, 3, y + 1, 'l1'); cv.rect(11, y, 12, y + 1, 'l1')
    cv.outline('ink')
    sprite('bloom_foe_toad_%d' % f, cv)


def heart_icons():
    for name, fill in (('full', 2), ('half', 1), ('empty', 0)):
        cv = Canvas(11, 10)
        shape = [(1, 1), (2, 0), (3, 0), (4, 1), (5, 2), (6, 1), (7, 0), (8, 0), (9, 1)]
        for y in range(10):
            for x in range(11):
                dx = x - 5
                inside = (y >= 2 and abs(dx) <= 4 - max(0, y - 5)) or (y in (0, 1) and abs(abs(dx) - 2.5) <= 1.5 - (1 - y))
                if not inside:
                    continue
                c = 'ud1'
                if fill == 2 or (fill == 1 and x <= 5):
                    c = 'berry_l' if (y <= 2 and dx < 0) else 'berry'
                cv.put(x, y, c)
        cv.outline('ink')
        sprite('bloom_ui_heart_' + name, cv)


def foes():
    for f in range(2):
        foe_slime(f); foe_beetle(f); foe_bat(f); foe_toad(f)
    heart_icons()


# ---------------------------------------------------------------- dungeons: cave mouth, floor, wall, portal, relics
def cave_mouth():
    cv = Canvas(26, 20)
    cv.disc(13, 13, 12.5, 8, 'r0'); cv.disc(13, 12, 11, 7, 'r1'); cv.disc(10, 9, 5, 3, 'r2'); cv.put(8, 7, 'r3')
    cv.disc(13, 16, 6, 5.5, 'obs_d'); cv.rect(7, 16, 19, 19, 'obs_d'); cv.disc(13, 16.5, 4.5, 4, 'ink')
    cv.rect(9, 17, 17, 19, 'ink')
    for x, y in ((4, 9), (21, 10), (17, 6)):
        cv.put(x, y, 'l2'); cv.put(x, y - 1, 'l3')
    cv.put(11, 15, 'fire1'); cv.put(15, 15, 'fire1')   # eyes in the dark
    cv.outline('ink')
    sprite('bloom_cave', cv)


def dungeon_tiles():
    import random as _r
    for v in range(2):
        rnd = _r.Random(40 + v)
        cv = Canvas(16, 16)
        cv.rect(0, 0, 15, 15, 'ud1')
        for _ in range(10):
            x, y = rnd.randrange(16), rnd.randrange(16)
            cv.put(x, y, 'ud2' if rnd.random() < 0.6 else 'ud0')
        cv.rect(0, 15, 15, 15, 'ud0'); cv.rect(15, 0, 15, 15, 'ud0')
        if v == 1:
            cv.put(4, 6, 'ud0'); cv.put(5, 7, 'ud0'); cv.put(6, 7, 'ud0'); cv.put(7, 8, 'ud0')
        sprite('bloom_dfloor_%d' % v, cv)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, 'obs'); cv.rect(0, 0, 15, 3, 'obs_l')
    for y in (5, 10):
        cv.rect(0, y, 15, y, 'obs_d')
    for x, y in ((4, 6), (11, 6), (7, 11), (1, 11), (14, 11)):
        cv.rect(x, y, x, y + 3, 'obs_d')
    sprite('bloom_dwall', cv)


def portal(f):
    cv = Canvas(16, 16)
    cv.disc(8, 8, 7, 7, 'gem_d'); cv.disc(8, 8, 5.5, 5.5, 'gem'); cv.disc(8, 8, 3.5, 3.5, 'gem_l')
    cv.disc(8, 8, 1.6 + f, 1.6 + f, 'white')
    for k in range(4):
        import math as _m
        a = k * _m.pi / 2 + f * 0.6
        cv.put(8 + _m.cos(a) * 6, 8 + _m.sin(a) * 6, 'white')
    cv.outline('ink')
    sprite('bloom_portal_%d' % f, cv)


def relics():
    cv = Canvas(14, 14)   # fang: +damage
    for k in range(9):
        w = max(0, 3 - k // 3)
        cv.rect(6 - w, 1 + k, 7 + w, 1 + k, 'cream' if k < 7 else 'white')
    cv.rect(4, 1, 9, 2, 'brick'); cv.put(6, 10, 'white'); cv.put(7, 11, 'white')
    cv.outline('ink'); sprite('bloom_relic_fang', cv)
    cv = Canvas(14, 14)   # shell: +heart
    cv.disc(6.5, 7.5, 5.5, 5, 'berry_d'); cv.disc(6.5, 7, 4.2, 3.8, 'berry'); cv.disc(5, 5.5, 1.6, 1.2, 'berry_l')
    for x in (4, 6, 8):
        cv.rect(x, 3, x, 11, 'berry_d')
    cv.outline('ink'); sprite('bloom_relic_shell', cv)
    cv = Canvas(14, 14)   # clover: +coins
    for (x, y) in ((4.5, 4.5), (9, 4.5), (4.5, 9), (9, 9)):
        cv.disc(x, y, 2.8, 2.8, 'l2'); cv.put(int(x) - 1, int(y) - 1, 'l4')
    cv.disc(6.8, 6.8, 1.5, 1.5, 'gold'); cv.rect(7, 10, 8, 13, 'l1')
    cv.outline('ink'); sprite('bloom_relic_clover', cv)
    cv = Canvas(14, 14)   # feather: +speed
    for k in range(11):
        cv.put(2 + k, 12 - k, 't1')
        cv.rect(3 + k, 12 - k - 3, 3 + k, 12 - k - 1, 'water_l' if k % 3 else 'cloth')
    cv.outline('ink'); sprite('bloom_relic_feather', cv)
    cv = Canvas(14, 14)   # eye: +crit
    cv.disc(6.5, 6.5, 6, 3.6, 'white'); cv.disc(6.5, 6.5, 3, 3, 'fire1'); cv.disc(6.5, 6.5, 1.5, 1.5, 'ink'); cv.put(5, 5, 'white')
    cv.outline('ink'); sprite('bloom_relic_eye', cv)


def dungeons():
    cave_mouth(); dungeon_tiles(); portal(0); portal(1); relics()


# ---------------------------------------------------------------- islanders and floor puzzles (stage 6)

C.update(folk_y="#f2d98c", folk_yd="#cfae5e", folk_g="#8ccf6a", folk_gd="#5c9a44", folk_o="#f0a868", folk_od="#c27440",
         folk_p="#ffb0c8", folk_pd="#e07896", folk_t="#e2bf8a", folk_td="#b08a58", folk_b="#bfe4ff", folk_bd="#86b4dc",
         folk_s="#f6e2b0", folk_sd="#d0b47a", folk_c="#9fb8cc", folk_cd="#6e88a0", folk_m="#a8d8a0", folk_md="#70a868",
         folk_h="#ffd860", folk_hd="#d8a830")

FOLK = {
    'olha': ('folk_y', 'folk_yd'), 'bor': ('folk_g', 'folk_gd'), 'grom': ('folk_o', 'folk_od'),
    'tosya': ('folk_p', 'folk_pd'), 'zlat': ('folk_t', 'folk_td'), 'inei': ('folk_b', 'folk_bd'),
    'yan': ('folk_s', 'folk_sd'), 'karas': ('folk_c', 'folk_cd'), 'moh': ('folk_m', 'folk_md'),
    'pchel': ('folk_h', 'folk_hd'),
}


def islander(nid, f):
    """An islander: a round seed-folk with little arms and their own hat or tool. f 0/1 = breathing."""
    body, dark = FOLK[nid]
    cv = Canvas(26, 26)
    x, y = 12, 26 - BASE - 1
    b = f
    cv.rect(x - 4, y - 1, x - 2, y, dark); cv.rect(x + 2, y - 1, x + 4, y, dark)          # feet
    cv.disc(x, y - 7 + b * 0.5, 6.2, 6.4 - b * 0.4, body)                               # body
    for yy in range(int(y - 6), int(y - 1)):
        cv.put(x + 5, yy, dark); cv.put(x + 4, yy + 1, dark)
    cv.rect(x - 4, y - 2, x + 4, y - 2, dark)
    cv.put(x - 4, y - 11, 'white'); cv.put(x - 3, y - 12, 'white')
    cv.rect(x - 8, y - 7, x - 7, y - 5, dark); cv.rect(x + 7, y - 7, x + 8, y - 5, dark)   # arms
    ey = int(y - 9 + b)
    if f == 1 and nid in ('olha', 'karas'):
        cv.rect(x - 3, ey, x - 2, ey, 'ink'); cv.rect(x + 2, ey, x + 3, ey, 'ink')       # squint smile
    else:
        cv.put(x - 2, ey, 'ink'); cv.put(x - 2, ey - 1, 'ink'); cv.put(x + 2, ey, 'ink'); cv.put(x + 2, ey - 1, 'ink')
    cv.put(x - 1, ey + 2, 'ink'); cv.put(x, ey + 3, 'ink'); cv.put(x + 1, ey + 2, 'ink')
    cv.put(x - 4, ey + 2, 'cheek'); cv.put(x + 4, ey + 2, 'cheek')
    top = int(y - 13 + b)
    if nid == 'olha':      # red dotted headscarf and a cane
        cv.disc(x, top + 1, 6.4, 2.6, 'berry'); cv.rect(x - 6, top + 2, x + 6, top + 3, 'berry_d')
        for dx in (-3, 1, 4): cv.put(x + dx, top, 'white')
        cv.rect(x + 9, y - 9, x + 9, y, 't1'); cv.rect(x + 8, y - 10, x + 9, y - 10, 't1')
    elif nid == 'bor':     # ranger hat with a feather
        cv.rect(x - 7, top + 2, x + 7, top + 2, 'p0'); cv.disc(x, top, 4.4, 2.6, 'p1'); cv.put(x - 1, top - 1, 'p2')
        cv.rect(x + 4, top - 4, x + 4, top - 1, 'berry'); cv.put(x + 5, top - 5, 'berry_l')
    elif nid == 'grom':    # leather apron, hammer
        cv.rect(x - 3, y - 7, x + 3, y - 2, 't0'); cv.rect(x - 2, y - 7, x + 2, y - 7, 't1')
        cv.rect(x + 9, y - 10, x + 9, y - 3, 't1'); cv.rect(x + 8, y - 12, x + 11, y - 10, 'r1'); cv.put(x + 8, y - 12, 'r3')
        cv.rect(x - 2, top + 1, x + 2, top + 1, dark)
    elif nid == 'tosya':   # two bows
        for dx in (-5, 5):
            cv.disc(x + dx - 1.3, top + 1, 1.5, 1.3, 'berry'); cv.disc(x + dx + 1.3, top + 1, 1.5, 1.3, 'berry'); cv.put(x + dx, top + 1, 'berry_d')
    elif nid == 'zlat':    # miner helmet with lamp
        cv.disc(x, top + 1, 6, 3, 'gold'); cv.rect(x - 7, top + 3, x + 7, top + 3, 'gold_d'); cv.put(x - 2, top - 1, 'gold_l')
        cv.disc(x, top + 1, 1.6, 1.4, 'white'); cv.put(x, top + 1, 'gold_l')
    elif nid == 'inei':    # star crown and a wand
        cv.rect(x - 4, top + 1, x + 4, top + 2, 'gem_l')
        for dx in (-4, 0, 4): cv.put(x + dx, top, 'gem_l'); cv.put(x + dx, top - 1, 'white')
        cv.rect(x - 9, y - 11, x - 9, y - 5, 'gold_d'); cv.disc(x - 9, y - 12, 1.6, 1.6, 'gold_l'); cv.put(x - 9, y - 12, 'white')
    elif nid == 'yan':     # glass-blower goggles and a glass bubble
        cv.rect(x - 6, ey - 1, x + 6, ey - 1, 't0')
        cv.disc(x - 2.5, ey - 1, 1.9, 1.7, 'gem'); cv.disc(x + 2.5, ey - 1, 1.9, 1.7, 'gem'); cv.put(x - 3, ey - 2, 'white'); cv.put(x + 2, ey - 2, 'white')
        cv.disc(x + 10, y - 9, 2, 2, 'water_l'); cv.put(x + 9, y - 10, 'white')
    elif nid == 'karas':   # bucket hat and a fishing rod
        cv.rect(x - 7, top + 2, x + 7, top + 2, 'cloth_d'); cv.disc(x, top + 0.5, 4.6, 2.4, 'cloth')
        for k in range(9): cv.put(x + 8 + k * 0.5, y - 6 - k, 't1')
        cv.rect(x + 13, y - 15, x + 13, y - 10, 'white')
    elif nid == 'moh':     # a mushroom cap for a hat
        cv.disc(x, top, 7, 3.4, 'berry'); cv.rect(x - 7, top + 1, x + 7, top + 2, 'berry_d')
        for dx, dy in ((-3, -1), (2, -2), (4, 0)): cv.put(x + dx, top + dy, 'white')
    elif nid == 'pchel':   # beekeeper hat with veil, a bee
        cv.rect(x - 7, top + 2, x + 7, top + 2, 'canvas_w'); cv.disc(x, top + 0.5, 4.6, 2.4, 'canvas_w')
        for xx in range(x - 6, x + 7, 2): cv.put(xx, top + 3, 'cotton_d'); cv.put(xx + 1, top + 4, 'cotton_d')
        cv.rect(x + 10, y - 15, x + 11, y - 14, 'gold'); cv.put(x + 10, y - 16, 'white'); cv.put(x + 12, y - 15, 'ink')
    cv.outline('ink')
    sprite('bloom_npc_%s_%d' % (nid, f), cv)


def puzzle_tiles():
    def slab(cv, c0, c1, c2):
        cv.rect(1, 3, 14, 14, c0); cv.rect(1, 2, 14, 12, c1); cv.rect(2, 2, 13, 3, c2)
    cv = Canvas(16, 16); slab(cv, 'r0', 'r1', 'r2')                       # pressure plate, off
    cv.disc(7.5, 7.5, 3.4, 3, 'r0'); cv.disc(7.5, 7, 2.4, 2, 'r2'); cv.outline('ink'); sprite('bloom_plate_0', cv)
    cv = Canvas(16, 16); slab(cv, 'gold_d', 'gold', 'gold_l')             # pressure plate, lit
    cv.disc(7.5, 7.5, 3.4, 3, 'gold_d'); cv.disc(7.5, 7, 2.4, 2, 'white'); cv.outline('ink'); sprite('bloom_plate_1', cv)
    for f, (c0, c1, c2, g) in enumerate((('ud0', 'ud1', 'ud2', 'ud3'), ('r1', 'r3', 'white', 'white'))):
        cv = Canvas(16, 16); slab(cv, c0, c1, c2)                         # rune tile: dim / flashing (tinted in code)
        for px, py in ((7, 4), (7, 5), (7, 6), (7, 7), (7, 8), (7, 9), (5, 6), (9, 6), (4, 9), (10, 9), (6, 10), (8, 10)):
            cv.put(px, py, g if f else 'ud3')
        cv.outline('ink'); sprite('bloom_rune_%d' % f, cv)
    for f in range(2):
        cv = Canvas(16, 16); slab(cv, 'r0', 'r1', 'r2')                   # floor lantern bowl: dark / burning
        cv.disc(7.5, 8, 4.4, 2.6, 'obs_d'); cv.disc(7.5, 7.4, 3.4, 1.6, 'ink' if not f else 'fire0')
        if f:
            cv.disc(7.5, 5.5, 2.4, 3, 'fire1'); cv.disc(7.5, 5.5, 1.3, 2, 'fire2'); cv.put(7, 3, 'white')
        cv.outline('ink'); sprite('bloom_lamp_%d' % f, cv)
    cv = Canvas(11, 13)                                                     # "!" quest bubble
    cv.disc(5, 5, 5, 5, 'gold'); cv.disc(4, 4, 3, 3, 'gold_l'); cv.rect(4, 10, 6, 10, 'gold'); cv.put(5, 11, 'gold')
    cv.rect(5, 2, 5, 6, 'ink'); cv.put(5, 8, 'ink'); cv.outline('ink'); sprite('bloom_bubble_quest', cv)
    cv = Canvas(11, 13)                                                     # gift bubble
    cv.disc(5, 5, 5, 5, 'white'); cv.rect(4, 10, 6, 10, 'white'); cv.put(5, 11, 'white')
    cv.rect(2, 4, 8, 8, 'berry'); cv.rect(2, 4, 8, 4, 'berry_l'); cv.rect(5, 3, 5, 8, 'gold'); cv.put(4, 2, 'gold'); cv.put(6, 2, 'gold')
    cv.outline('ink'); sprite('bloom_bubble_gift', cv)


def pet(kind, f):
    """Companions that trot after the hero: bee (friend pack), fox (dew), owl (level 20 pack)."""
    cv = Canvas(16, 14)
    b = f
    if kind == 'bee':
        cv.disc(8, 8 - b, 4.6, 3.8, 'gold'); cv.rect(6, 5 - b, 6, 11 - b, 'ink'); cv.rect(9, 5 - b, 9, 11 - b, 'ink')
        cv.disc(6, 4 - b + f, 2.6, 1.8, 'white', 220); cv.disc(10, 4 - b + f, 2.6, 1.8, 'white', 220)
        cv.put(12, 7 - b, 'ink'); cv.put(12, 6 - b, 'white'); cv.put(13, 9 - b, 'cheek')
        cv.put(3, 8 - b, 'gold_d')
    elif kind == 'fox':
        cv.disc(7, 9, 4.6, 3, 'iron'); cv.disc(11, 6 - b, 3.4, 3, 'iron'); cv.put(9, 3 - b, 'iron'); cv.put(9, 2 - b, 'iron_l')
        cv.put(13, 3 - b, 'iron'); cv.put(13, 2 - b, 'iron_l'); cv.disc(11.5, 7.5 - b, 2, 1.2, 'white')
        cv.put(12, 5 - b, 'ink'); cv.put(14, 7 - b, 'ink'); cv.disc(2.5, 7 - f, 2.6, 2, 'iron'); cv.put(1, 6 - f, 'white')
        cv.rect(5, 12, 5, 12, 't0'); cv.rect(9, 12, 9, 12, 't0')
    else:  # owl
        cv.disc(8, 8 - b, 5, 5, 't1'); cv.disc(8, 9.5 - b, 3.4, 3, 't2')
        cv.disc(6, 6 - b, 1.8, 1.8, 'white'); cv.disc(10, 6 - b, 1.8, 1.8, 'white')
        cv.put(6, 6 - b, 'ink'); cv.put(10, 6 - b, 'ink'); cv.put(8, 8 - b, 'gold')
        cv.put(4, 2 - b, 't0'); cv.put(12, 2 - b, 't0'); cv.rect(6, 13, 6, 13, 'gold_d'); cv.rect(10, 13, 10, 13, 'gold_d')
    cv.outline('ink')
    sprite('bloom_pet_%s_%d' % (kind, f), cv)


def decor_items():
    """Island decorations bought with dew. Ground at the bottom centre with BASE px."""
    def done(cv, n):
        cv.outline('ink'); sprite('bloom_decor_' + n, cv)
    cv = Canvas(12, 24); cv.rect(5, 6, 6, 21, 'r0'); cv.rect(5, 6, 5, 21, 'r1'); cv.rect(3, 20, 8, 21, 'r0')
    cv.rect(3, 1, 8, 6, 'r0'); cv.rect(4, 2, 7, 5, 'fire2'); cv.put(5, 3, 'white'); done(cv, 'lamp')
    cv = Canvas(18, 12); cv.disc(9, 7, 8, 3.4, 'd1'); cv.disc(9, 6.4, 7, 2.6, 'd2')
    for x, c in ((4, 'berry'), (7, 'gold'), (10, 'berry_l'), (13, 'white'), (6, 'gem'), (12, 'gold')):
        cv.put(x, 5 if x % 2 else 4, c); cv.put(x, 6, 'l2')
    done(cv, 'bed')
    cv = Canvas(12, 24); cv.rect(2, 2, 2, 21, 't1'); cv.put(2, 1, 'gold_l')
    for k in range(8):
        h = 3 - abs(k - 3) // 2
        cv.rect(3 + k, 3 + (3 - h), 3 + k, 3 + 3 + h, 'gem' if k < 4 else 'gem_l')
    cv.rect(1, 20, 3, 21, 't0'); done(cv, 'flag')
    cv = Canvas(20, 14); cv.rect(2, 5, 17, 7, 't1'); cv.rect(2, 5, 17, 5, 't2'); cv.rect(2, 1, 17, 3, 't1'); cv.rect(2, 1, 17, 1, 't2')
    cv.rect(3, 8, 4, 11, 't0'); cv.rect(15, 8, 16, 11, 't0'); done(cv, 'bench')
    cv = Canvas(18, 26); cv.rect(8, 8, 9, 23, 't1'); cv.rect(2, 11, 15, 12, 't1')
    cv.disc(8.5, 6, 3.6, 3.6, 'iron'); cv.put(7, 5, 'ink'); cv.put(10, 5, 'ink'); cv.rect(7, 7, 10, 7, 'ink')
    cv.rect(4, 1, 13, 2, 'gold_d'); cv.rect(6, 0, 11, 1, 'gold'); cv.rect(6, 13, 11, 18, 'berry'); cv.rect(6, 13, 11, 13, 'berry_d')
    done(cv, 'scarecrow')
    cv = Canvas(22, 18); cv.disc(11, 13, 10, 4, 'r0'); cv.disc(11, 12.5, 8.6, 3, 'water'); cv.disc(9, 12, 3, 1.2, 'water_l')
    cv.rect(10, 4, 12, 11, 'r1'); cv.disc(11, 4, 3, 1.4, 'r2'); cv.put(11, 1, 'water_l'); cv.put(10, 2, 'water_l'); cv.put(12, 2, 'water_l')
    done(cv, 'fountain')
    cv = Canvas(14, 16); cv.rect(6, 7, 8, 13, 'cotton_d'); cv.disc(7, 6, 6, 3.4, 'gem'); cv.rect(1, 6, 13, 7, 'gem_d')
    cv.put(4, 4, 'gem_l'); cv.put(9, 3, 'gem_l'); cv.put(11, 5, 'gem_l'); done(cv, 'shroom')
    cv = Canvas(14, 26); cv.rect(3, 19, 10, 23, 'r1'); cv.rect(3, 19, 10, 19, 'r2'); cv.rect(5, 10, 8, 18, 'gold_d')
    for k in range(5):
        import math as _m
        a = -_m.pi / 2 + k * 2 * _m.pi / 5
        cv.disc(6.5 + _m.cos(a) * 3.2, 6 + _m.sin(a) * 3.2, 1.6, 1.6, 'gold')
    cv.disc(6.5, 6, 2.4, 2.4, 'gold'); cv.put(6, 5, 'gold_l'); done(cv, 'statue')


def folk():
    for k in ('bee', 'fox', 'owl'):
        for f in range(2):
            pet(k, f)
    decor_items()
    for n in FOLK:
        for f in range(2):
            islander(n, f)
    puzzle_tiles()


if __name__ == '__main__':
    world = build_all()
    for name, im in SPRITES.items():
        save_imageset(name, im)
    os.makedirs(os.path.dirname(WORLD_JSON), exist_ok=True)
    with open(WORLD_JSON, 'w') as f:
        json.dump(world, f, ensure_ascii=False, indent=1)
    print(len(SPRITES), 'sprites')
    if len(sys.argv) > 1:
        preview(world, sys.argv[1])
