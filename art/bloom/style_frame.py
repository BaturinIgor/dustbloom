"""DUSTBLOOM (Forager-like pivot) style frame: one island, chunky pixel art
(1 art px = 4 pt), saturated palette, dark outlines, juicy pickups.
Original designs. Run: python3 art/bloom/style_frame.py out.png"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 98, 213          # art pixels (iPhone 393 x 852 pt at 4 pt per px)
K = 12                  # device px per art px (@3x)
FONT = __file__.rsplit('/art/', 1)[0] + '/client/Dustbloom/Fonts/Rubik-Bold.ttf'
T = 16

C = dict(
    ink="#2a1d2e",
    water="#38a9c6", water_d="#2b8db0", water_l="#6fd0e0", foam="#effcff",
    g0="#3f9a3a", g1="#56b944", g2="#7bd456", g3="#aeea6c",
    d0="#5e3420", d1="#8a4f2c", d2="#b8743f", d3="#d99a5a",
    t0="#5e3420", t1="#8a5532",
    l0="#24703a", l1="#33914a", l2="#4fb556", l3="#7bd76a", l4="#b5f08a",
    r0="#4f5668", r1="#7b8397", r2="#a6aebf", r3="#d3d9e4",
    iron="#e0874a", gold="#ffd040", berry="#e8394f", berry_l="#ff8a9a",
    cream="#ffc9d8", cream_d="#f394b0", cream_dd="#d0607f",
    fire0="#e2462a", fire1="#ff9a2e", fire2="#ffe066",
)

def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

im = Image.new('RGBA', (W, H), hexc(C['water']))
px = im.load()

def put(x, y, c, a=255):
    x, y = int(x), int(y)
    if 0 <= x < W and 0 <= y < H:
        if a >= 255:
            px[x, y] = hexc(C.get(c, c))
        else:
            r, g, b, _ = px[x, y]
            cr, cg, cb, _ = hexc(C.get(c, c))
            k = a / 255
            px[x, y] = (round(r + (cr - r) * k), round(g + (cg - g) * k), round(b + (cb - b) * k), 255)

def rect(x0, y0, x1, y1, c, a=255):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            put(x, y, c, a)

def disc(cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                put(x, y, c)

rnd = random.Random(3)

# ---------------------------------------------------------------- water
for _ in range(90):
    x, y = rnd.randrange(W), rnd.randrange(H)
    n = rnd.choice((2, 3, 4))
    c = rnd.choice(('water_l', 'water_d', 'water_d'))
    for k in range(n):
        put(x + k, y, c)

# ---------------------------------------------------------------- islands
def island(cells, ox, oy, locked=False):
    """cells: set of (cx, cy) 16 px tiles. Draws foam, cliff, grass."""
    mask = set()
    for (cx, cy) in cells:
        for y in range(T):
            for x in range(T):
                mask.add((ox + cx * T + x, oy + cy * T + y))
    # round the outer corners a bit
    for (cx, cy) in cells:
        for (dx, dy) in ((0, 0), (T - 1, 0), (0, T - 1), (T - 1, T - 1)):
            sx, sy = (-1 if dx == 0 else 1), (-1 if dy == 0 else 1)
            if (cx + sx, cy) not in cells and (cx, cy + sy) not in cells:
                x0, y0 = ox + cx * T + dx, oy + cy * T + dy
                for k in range(3):
                    for j in range(3 - k):
                        mask.discard((x0 - sx * k, y0 - sy * j))
    cliff = 6
    # foam ring and soft shadow in the water
    for (x, y) in list(mask):
        for dy in range(1, cliff + 3):
            if (x, y + dy) not in mask:
                put(x + 1, y + dy + 1, 'water_d')
    for (x, y) in list(mask):
        for (dx, dy) in ((1, 0), (-1, 0), (0, -1), (0, cliff + 1), (1, cliff + 1), (-1, cliff + 1)):
            q = (x + dx, y + dy)
            if q not in mask and (x + dx, y + dy - cliff) not in mask:
                put(*q, 'foam')
    # cliff face under the bottom edges
    for (x, y) in mask:
        if (x, y + 1) not in mask:
            for k in range(1, cliff + 1):
                c = 'd2' if k <= 2 else ('d1' if k <= 4 else 'd0')
                if k == 1 and (x % 5 == 0):
                    c = 'd3'
                put(x, y + k, c)
            put(x, y + cliff + 1, 'ink')
            if x % 7 == 3:
                put(x, y + 3, 'd0')
    # grass
    for (x, y) in mask:
        n = math.sin(x * 0.7 + y * 0.3) + math.sin(x * 0.23 - y * 0.61) * 1.3
        c = 'g1' if n < 1.2 else 'g2'
        if n < -1.4:
            c = 'g0'
        put(x, y, c)
    # top rim highlight and side outlines
    for (x, y) in mask:
        if (x, y - 1) not in mask:
            put(x, y, 'g3')
            put(x, y - 1, 'ink')
        if (x - 1, y) not in mask:
            put(x - 1, y, 'ink')
        if (x + 1, y) not in mask:
            put(x + 1, y, 'ink')
            put(x, y, 'g0')
    # grass tufts
    for _ in range(len(cells) * 5):
        (x, y) = rnd.choice(sorted(mask))
        if all((x + a, y + b) in mask for a in (-2, 2) for b in (-2, 2)):
            put(x, y, 'g3'); put(x - 1, y + 1, 'g2'); put(x + 1, y + 1, 'g2')
    if locked:
        for (x, y) in mask:
            if not (0 <= x < W and 0 <= y < H): continue
            r, g, b, _ = px[x, y]
            px[x, y] = (r // 2 + 20, g // 2 + 30, b // 2 + 50, 255)
    return mask

main = {(c, r) for c in range(5) for r in range(6)} - {(0, 0), (4, 5), (0, 5)} | {(2, -1)}
island_mask = island(main, 9, 60)
island({(0, 0), (1, 0), (2, 0), (1, 1)}, 52, 172, locked=True)
island({(0, 0), (1, 0), (0, 1)}, 80, 20, locked=True)

# ---------------------------------------------------------------- props
def shadow(cx, cy, rx):
    for x in range(int(cx - rx), int(cx + rx) + 1):
        put(x, cy, 'g0'); put(x, cy + 1, 'g0') if abs(x - cx) < rx - 1 else None

def tree(x, y):
    shadow(x, y, 6)
    rect(x - 1, y - 7, x + 1, y, 't1'); rect(x + 1, y - 7, x + 1, y, 't0')
    put(x - 2, y, 't1'); put(x + 2, y, 't0')
    disc(x, y - 13, 7.5, 6.5, 'ink')
    disc(x, y - 13, 6.5, 5.5, 'l1')
    disc(x - 1, y - 14, 5, 4, 'l2')
    disc(x - 2, y - 15, 3, 2.4, 'l3')
    put(x - 3, y - 16, 'l4'); put(x - 2, y - 17, 'l4')
    for (a, b) in ((3, -10), (4, -12), (-4, -9)):
        put(x + a, y + b, 'l0')

def rock(x, y, ore=None):
    shadow(x, y, 6)
    disc(x, y - 4, 6.5, 5, 'ink')
    disc(x, y - 4, 5.5, 4, 'r1')
    disc(x - 1, y - 5, 4, 3, 'r2')
    put(x - 3, y - 7, 'r3'); put(x - 2, y - 7, 'r3'); put(x - 3, y - 6, 'r3')
    rect(x - 5, y - 1, x + 5, y - 1, 'r0')
    if ore:
        for (a, b) in ((1, -5), (3, -3), (-2, -3), (2, -7)):
            put(x + a, y + b, ore)
        put(x + 2, y - 6, 'r3')

def bush(x, y):
    shadow(x, y, 5)
    disc(x, y - 4, 5.5, 4.5, 'ink')
    disc(x, y - 4, 4.5, 3.5, 'l1')
    disc(x - 1, y - 5, 3, 2.2, 'l2')
    for (a, b) in ((-2, -4), (2, -5), (1, -2), (-3, -2), (3, -3)):
        put(x + a, y + b, 'berry'); put(x + a, y + b - 1, 'berry_l')

def flower(x, y, c):
    put(x, y, 'g0'); put(x, y - 1, c); put(x - 1, y - 2, c); put(x + 1, y - 2, c); put(x, y - 3, c); put(x, y - 2, 'gold')

def furnace(x, y):
    shadow(x, y + 1, 8)
    rect(x - 7, y - 12, x + 7, y, 'ink')
    rect(x - 6, y - 11, x + 6, y - 1, 'r1')
    rect(x - 6, y - 11, x + 6, y - 10, 'r2')
    for (a, b) in ((-4, -7), (2, -8), (-1, -4), (4, -3)):
        rect(x + a, y + b, x + a + 1, y + b, 'r0')
    rect(x - 3, y - 6, x + 3, y - 1, 'ink')
    rect(x - 2, y - 5, x + 2, y - 1, 'fire0')
    rect(x - 1, y - 4, x + 1, y - 1, 'fire1')
    put(x, y - 3, 'fire2'); put(x, y - 2, 'fire2')
    rect(x + 2, y - 17, x + 4, y - 12, 'ink'); rect(x + 3, y - 16, x + 3, y - 12, 'r0')
    for k, (a, b) in enumerate(((3, -19), (4, -21), (2, -23))):
        put(x + a, y + b, 'r3', 200 - k * 50)

def anvil(x, y):
    shadow(x, y + 1, 6)
    rect(x - 2, y - 3, x + 2, y, 'ink'); rect(x - 1, y - 3, x + 1, y - 1, 'r0')
    rect(x - 6, y - 7, x + 5, y - 4, 'ink'); rect(x - 5, y - 6, x + 4, y - 5, 'r1'); rect(x - 5, y - 6, x + 4, y - 6, 'r2')
    put(x - 7, y - 6, 'ink'); put(x - 6, y - 6, 'r1')

def sign_price(x, y):
    rect(x, y - 9, x, y, 't1')
    rect(x - 7, y - 16, x + 7, y - 8, 'ink'); rect(x - 6, y - 15, x + 6, y - 9, 'd3'); rect(x - 6, y - 9, x + 6, y - 9, 'd2')
    disc(x - 3, y - 12, 2.2, 2.2, 'gold'); put(x - 4, y - 13, 'fire2')

# layout on the main island (art px; island spans x 9..89, y 44..156)
props = [
    ('tree', 20, 82), ('tree', 78, 76), ('tree', 30, 146), ('tree', 84, 126),
    ('rock', 62, 96, None), ('rock', 72, 140, 'iron'), ('rock', 24, 112, 'gold'),
    ('bush', 50, 140), ('bush', 46, 58 + 6),
    ('furnace', 58, 120), ('anvil', 38, 124),
]
for f in [(26, 96, 'white'), (70, 108, 'berry_l'), (36, 74, 'white'), (64, 70, 'gold'), (16, 132, 'berry_l'), (80, 96, 'white')]:
    flower(f[0], f[1], C.get(f[2], '#ffffff') if f[2] != 'white' else '#ffffff')
props.sort(key=lambda p: p[2])
player = (44, 104)
drawn_player = False
def bloomling(x, y, swing=True):
    shadow(x, y, 4)
    rect(x - 3, y - 1, x - 2, y, 'ink'); rect(x + 2, y - 1, x + 3, y, 'ink')     # feet
    disc(x, y - 6, 5.5, 5.5, 'ink')
    disc(x, y - 6, 4.5, 4.6, 'cream')
    disc(x + 1, y - 5, 3.5, 3.2, 'cream')
    for yy in range(y - 4, y - 1):
        put(x + 4, yy, 'cream_d'); put(x + 3, yy + 1, 'cream_d')
    rect(x - 2, y - 1, x + 2, y - 1, 'cream_d')
    put(x - 3, y - 9, '#ffffff'); put(x - 2, y - 10, '#ffffff')
    rect(x - 2, y - 7, x - 2, y - 6, 'ink'); put(x - 2, y - 7, '#ffffff')    # eyes
    rect(x + 2, y - 7, x + 2, y - 6, 'ink'); put(x + 2, y - 7, '#ffffff')
    put(x - 1, y - 4, 'ink'); put(x, y - 3, 'ink'); put(x + 1, y - 4, 'ink')   # smile
    put(x - 4, y - 5, '#ff6f91'); put(x + 4, y - 5, '#ff6f91')                   # cheeks
    # sprout on the head
    rect(x, y - 13, x, y - 11, 'l0')
    disc(x - 3, y - 15, 3, 1.8, 'ink'); disc(x - 3, y - 15, 2.2, 1.1, 'l2')
    disc(x + 3, y - 16, 3, 1.8, 'ink'); disc(x + 3, y - 16, 2.2, 1.1, 'l3')
    disc(x + 1, y - 19, 1.8, 1.8, 'ink'); put(x + 1, y - 19, 'berry_l'); put(x + 1, y - 20, '#ffd6e0')
    if swing:  # pickaxe raised toward the rock on the right
        for k in range(7):
            put(x + 5 + k * 0.6, y - 4 - k, 't1')
        rect(x + 6, y - 13, x + 12, y - 12, 'ink'); rect(x + 7, y - 12, x + 11, y - 12, 'r2')
        put(x + 12, y - 11, 'ink'); put(x + 6, y - 11, 'ink')

for p in props:
    if not drawn_player and p[2] > player[1]:
        bloomling(*player); drawn_player = True
    k = p[0]
    if k == 'tree': tree(p[1], p[2])
    elif k == 'rock': rock(p[1], p[2], C[p[3]] if p[3] else None)
    elif k == 'bush': bush(p[1], p[2])
    elif k == 'furnace': furnace(p[1], p[2])
    elif k == 'anvil': anvil(p[1], p[2])
if not drawn_player:
    bloomling(*player)
sign_price(70, 182)

# hit on the rock the player is mining: sparks + HP bar
rx, ry = 62, 96
for (a, b) in ((-6, -9), (-8, -6), (-4, -12)):
    put(rx + a, ry + b, '#ffffff'); put(rx + a + 1, ry + b, 'fire2')
rect(rx - 6, ry - 14, rx + 6, ry - 12, 'ink'); rect(rx - 5, ry - 13, rx + 1, ry - 13, '#ff6a4a')

# drops on the ground and one flying to the player
def drop(x, y, kind, hop=0):
    put(x, y + 1, 'g0'); put(x + 1, y + 1, 'g0'); put(x - 1, y + 1, 'g0')
    y -= hop
    if kind == 'stone':
        disc(x, y - 1, 2.2, 1.8, 'ink'); disc(x, y - 1, 1.4, 1, 'r2'); put(x - 1, y - 2, 'r3')
    elif kind == 'wood':
        rect(x - 3, y - 2, x + 2, y, 'ink'); rect(x - 2, y - 2, x + 1, y - 1, 't1'); put(x + 2, y - 1, 'd3'); put(x + 2, y - 2, 'd2')
    elif kind == 'berry':
        disc(x, y - 1, 1.8, 1.8, 'ink'); put(x, y - 1, 'berry'); put(x - 1, y - 1, 'berry'); put(x, y - 2, 'berry_l')
    elif kind == 'coin':
        disc(x, y - 2, 2.4, 2.4, 'ink'); disc(x, y - 2, 1.6, 1.6, 'gold'); put(x - 1, y - 3, 'fire2')
drop(56, 104, 'stone'); drop(52, 99, 'stone', hop=4); drop(60, 108, 'coin', hop=2)
drop(27, 90, 'wood'); drop(31, 93, 'wood', hop=3)
drop(48, 146, 'berry')

# ---------------------------------------------------------------- upscale + HUD at device resolution
big = im.resize((W * K, H * K), Image.NEAREST)
d = ImageDraw.Draw(big)
def font(s): return ImageFont.truetype(FONT, s)
def label(x, y, t, s, fill=(255, 255, 255), stroke=(42, 29, 46), sw=8, anchor='mm'):
    d.text((x, y), t, font=font(s), fill=fill, stroke_width=sw, stroke_fill=stroke, anchor=anchor)
def pill(x0, y0, x1, y1, fill=(42, 29, 46, 200), r=40):
    o = Image.new('RGBA', big.size, (0, 0, 0, 0))
    ImageDraw.Draw(o).rounded_rectangle((x0, y0, x1, y1), r, fill=fill)
    big.alpha_composite(o)
# floating pickup text
label(52 * K, 86 * K, '+2', 56)
label(31 * K, 84 * K, '+1', 56)
label(rx * K + 70, (ry - 18) * K, '', 40)
# top HUD: hearts + energy left, level ring + XP bar centre, coins right
top = 160
for i in range(3):
    hx = 40 + i * 70
    heart = Image.new('RGBA', (9, 8), (0, 0, 0, 0)); hp = heart.load()
    shape = ["011000110", "122101221", "122212221", "122222221", "012222210", "001222100", "000121000", "000010000"]
    for yy, row in enumerate(shape):
        for xx, v in enumerate(row):
            if v != '0':
                hp[xx, yy] = hexc('#2a1d2e') if v == '1' else hexc('#ff4a5e' if i < 2 or xx < 4 else '#7a5a6a')
    big.alpha_composite(heart.resize((9 * 7, 8 * 7), Image.NEAREST), (hx, top + 4))
pill(40, top + 80, 250, top + 112, r=16)
pill(46, top + 86, 190, top + 106, fill=(255, 214, 80, 255), r=12)
pill(W * K // 2 - 150, top + 6, W * K // 2 + 250, top + 62, r=28)
pill(W * K // 2 - 142, top + 14, W * K // 2 + 110, top + 54, fill=(110, 220, 110, 255), r=20)
o = Image.new('RGBA', big.size, (0, 0, 0, 0)); od = ImageDraw.Draw(o)
od.ellipse((W * K // 2 - 220, top - 14, W * K // 2 - 120, top + 86), fill=(42, 29, 46, 255))
od.ellipse((W * K // 2 - 212, top - 6, W * K // 2 - 128, top + 78), fill=(255, 214, 80, 255))
big.alpha_composite(o)
label(W * K // 2 - 170, top + 36, '7', 54, fill=(42, 29, 46), sw=0)
label(W * K // 2 + 50, top + 35, '1 240 / 2 000', 32, sw=6)
pill(W * K - 300, top + 2, W * K - 30, top + 68, r=33)
coin = Image.new('RGBA', (7, 7), (0, 0, 0, 0)); cp = coin.load()
for yy in range(7):
    for xx in range(7):
        dd = (xx - 3) ** 2 + (yy - 3) ** 2
        if dd <= 10: cp[xx, yy] = hexc('#2a1d2e') if dd > 6 else hexc('#ffd040')
cp[2, 2] = hexc('#ffe066')
big.alpha_composite(coin.resize((70, 70), Image.NEAREST), (W * K - 292, top))
label(W * K - 140, top + 35, '1 870', 46, sw=7)
# bottom: hotbar with resources and a build button
bar_y = H * K - 330
pill(40, bar_y, W * K - 40, bar_y + 170, fill=(42, 29, 46, 215), r=50)
items = [('wood', '24'), ('stone', '31'), ('iron', '6'), ('berry', '9'), ('coin', '')]
for i, (k, n) in enumerate(items[:4]):
    cx = 150 + i * 200
    pill(cx - 75, bar_y + 18, cx + 75, bar_y + 152, fill=(255, 255, 255, 40), r=30)
    ic = Image.new('RGBA', (12, 12), (0, 0, 0, 0)); ip = ic.load()
    def ip_put(x, y, c):
        if 0 <= x < 12 and 0 <= y < 12: ip[x, y] = hexc(C.get(c, c))
    if k == 'wood':
        for x in range(1, 11):
            for y in range(4, 9): ip_put(x, y, 'ink' if y in (4, 8) or x in (1, 10) else 't1')
        for y in range(5, 8): ip_put(9, y, 'd3')
    elif k == 'stone':
        for x in range(1, 11):
            for y in range(2, 10):
                if ((x - 5.5) / 5) ** 2 + ((y - 6) / 4) ** 2 <= 1: ip_put(x, y, 'r2')
        for x in range(1, 11):
            for y in range(2, 10):
                if 0.75 < ((x - 5.5) / 5) ** 2 + ((y - 6) / 4) ** 2 <= 1: ip_put(x, y, 'ink')
        ip_put(4, 4, 'r3'); ip_put(5, 4, 'r3')
    elif k == 'iron':
        for x in range(2, 10):
            for y in range(3, 9): ip_put(x, y, 'ink' if y in (3, 8) or x in (2, 9) else '#c9ccd6')
        for x in range(3, 9): ip_put(x, 4, '#ffffff')
    elif k == 'berry':
        for (bx, by) in ((4, 6), (7, 6), (5, 3)):
            for x in range(bx - 2, bx + 3):
                for y in range(by - 2, by + 3):
                    if (x - bx) ** 2 + (y - by) ** 2 <= 4: ip_put(x, y, 'ink' if (x - bx) ** 2 + (y - by) ** 2 > 2 else 'berry')
            ip_put(bx - 1, by - 1, 'berry_l')
    big.alpha_composite(ic.resize((96, 96), Image.NEAREST), (cx - 48, bar_y + 22))
    label(cx + 40, bar_y + 128, n, 38, sw=6)
# joystick ghost (left) and build hammer button (right)
o = Image.new('RGBA', big.size, (0, 0, 0, 0)); od = ImageDraw.Draw(o)
jy = bar_y - 260
od.ellipse((90, jy - 120, 330, jy + 120), outline=(255, 255, 255, 120), width=10)
od.ellipse((170, jy - 40, 250, jy + 40), fill=(255, 255, 255, 150))
od.ellipse((W * K - 300, jy - 110, W * K - 80, jy + 110), fill=(255, 160, 60, 255), outline=(42, 29, 46, 255), width=12)
big.alpha_composite(o)
label(W * K - 190, jy, 'Строить', 40, sw=7)
# price on the locked island sign
label(71 * K + 20, 170 * K, '50', 40, fill=(42, 29, 46), sw=0)
big.convert('RGB').save(sys.argv[1])
