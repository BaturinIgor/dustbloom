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
def hero(frame):
    """Bloomling: pink bud with a sprout. frame: idle_0/1, run_0..3."""
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
    # face
    if frame == 'idle_1':
        cv.rect(x - 3, by - 6, x - 2, by - 6, 'ink'); cv.rect(x + 2, by - 6, x + 3, by - 6, 'ink')
    else:
        for ex in (x - 2, x + 2):
            cv.rect(ex, by - 7, ex, by - 6, 'ink'); cv.put(ex, by - 7, 'white')
            cv.put(ex + (1 if ex < x else 1), by - 6, 'ink')
    cv.put(x - 1, by - 4, 'ink'); cv.put(x, by - 3, 'ink'); cv.put(x + 1, by - 4, 'ink')
    cv.put(x - 4, by - 5, 'cheek'); cv.put(x + 4, by - 5, 'cheek')
    # sprout
    cv.rect(x, by - 13, x, by - 11, 'l0')
    cv.disc(x - 2.5, by - 13.5, 2.6, 1.4, 'l2'); cv.put(x - 3, by - 14, 'l3')
    cv.disc(x + 2.5, by - 14.5, 2.6, 1.4, 'l3'); cv.put(x + 2, by - 15, 'l4')
    cv.disc(x, by - 16.5, 1.6, 1.6, 'berry_l'); cv.put(x, by - 17, 'white')
    cv.outline('ink')
    sprite('bloom_hero_' + frame, cv)


HELPER_COLORS = {
    'pink': ('#ffc9d8', '#f394b0'), 'sun': ('#ffe58a', '#f2b84a'),
    'sky': ('#bfe6ff', '#86c2ef'), 'plum': ('#e2c4ff', '#b48ae6'),
}


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
    cv = Canvas(20, 26)
    x, y = 10, 26 - BASE - 1
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


# ---------------------------------------------------------------- world
# World map, one char per 16 px tile, top row = north. Digits are islands,
# '|' and '=' are bridge spots (one water tile between two islands).
MAP = """
......1111111.................
....111111111.....5555........
...1111111111...5555555.......
...11111111111=555555555......
....1111111111..55555555......
.....11111111....555555.......
.......|..........|...........
......00000.......222.........
......0000000...22222.........
..4...0000000...222222........
.444..0000000=2222222.........
44444=0000000...222222........
44444.0000000...222222........
.4444.00000000..222222........
..444..000000...22222.........
...44...0000.....222..........
........|.....................
.....33333333.................
...333333333333...............
...3333333333333..............
....33333333333...............
......333333..................
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
]
# per-island grass tint so every island reads differently
TINTS = {
    1: dict(g0='#4c9a3a', g1='#6dbd45', g1b='#73c34a', g2='#86cf52', g3='#b9ea7a', gline='#2a6034'),
    2: dict(g0='#6aa844', g1='#8cc957', g1b='#92cd5c', g2='#a3d668', g3='#d2f09a'),
    3: dict(g0='#62b444', g1='#86d353', g1b='#8cd858', g2='#a2e264', g3='#d6f79a'),
    4: dict(g0='#8aa83c', g1='#a9c95a', g1b='#aecd60', g2='#c2dc72', g3='#e6f3a4', gline='#5b6b2a'),
    5: dict(g0='#3f9e7a', g1='#5cc59a', g1b='#62ca9f', g2='#7fd8b0', g3='#bff2da', gline='#245f52'),
}


def _parse():
    rows = [r for r in MAP.strip('\n').split('\n')]
    h = len(rows)
    cells = {}
    bridges = []
    for r, row in enumerate(rows):
        for x, ch in enumerate(row):
            y = h - 1 - r
            if ch.isdigit():
                cells.setdefault(int(ch), set()).add((x, y))
    def at(x, y):
        r = h - 1 - y
        if 0 <= r < h and 0 <= x < len(rows[r]) and rows[r][x].isdigit():
            return int(rows[r][x])
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
    # world position of the image's bottom-left corner (y up)
    wx = minx * T - pad
    wy = miny * T - pad - CLIFF - 2
    return cv.im, (wx, wy)


def build_all():
    for f in ('idle_0', 'idle_1', 'run_0', 'run_1', 'run_2', 'run_3'):
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
              'plank', 'cloth', 'crystal', 'flower'):
        item(n)
    fx()
    for n in FINDS:
        find(n)
    ui_icons()
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
