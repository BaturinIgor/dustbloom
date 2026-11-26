"""Pixel drawing helpers for the high-detail (32 px per tile) art."""
import math

from PIL import Image

from .palette import INK, dither, hexrgb, ramp_d

_cache = {}


def rgb(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else (*c, a)
    if c not in _cache:
        _cache[c] = hexrgb(c)
    return (*_cache[c], a)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, x, y, c, a=255):
    x, y = int(x), int(y)
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), rgb(c, a))


def get(im, x, y):
    if 0 <= x < im.width and 0 <= y < im.height:
        return im.getpixel((int(x), int(y)))
    return (0, 0, 0, 0)


def mix(im, x, y, c, a):
    """Blend colour c over pixel (x, y) with opacity a (0..1), keep alpha."""
    x, y = int(x), int(y)
    if not (0 <= x < im.width and 0 <= y < im.height):
        return
    r, g, b, da = im.getpixel((x, y))
    cr, cg, cb, _ = rgb(c)
    if da == 0:
        return
    im.putpixel((x, y), (round(r + (cr - r) * a), round(g + (cg - g) * a), round(b + (cb - b) * a), da))


def rect(im, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            put(im, x, y, c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(int(n) + 1):
        put(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def ball(im, cx, cy, rx, ry, rname, light=(-0.65, -0.75), lo=0.0, hi=1.0, spread=1.0, mask=None):
    """Shaded ellipse lit from the top-left, dithered between ramp bands."""
    lx, ly = light
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d > 1 or (mask and not mask(x, y)):
                continue
            nz = math.sqrt(max(0.0, 1 - d))
            lum = -(lx * dx + ly * dy) * 0.55 + nz * 0.6 - 0.05
            t = lo + (hi - lo) * max(0.0, min(1.0, (lum + 0.4) / 1.25))
            put(im, x, y, ramp_d(rname, t, x, y, spread))


def outline(im, color=INK, only_outside=True):
    """1 px dark outline around the opaque silhouette."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                if get(src, x + dx, y + dy)[3] > 200:
                    put(im, x, y, color)
                    break
    return im


def pad_canvas(im, l=0, t=0, r=0, b=0):
    out = new(im.width + l + r, im.height + t + b)
    out.alpha_composite(im, (l, t))
    return out


def cast_shadow(im, base_y=None, shear=0.9, squash=0.32, color="#2c1e4a", alpha=120):
    """Long sunset shadow: silhouette laid on the ground to the lower right."""
    w, h = im.size
    base_y = h if base_y is None else base_y
    out = new(w + int(base_y * shear) + 4, h + 8)
    for y in range(base_y):
        for x in range(w):
            if im.getpixel((x, y))[3] > 100:
                dist = base_y - y
                ny = base_y - 1 + int(dist * squash * 0.25)
                nx = x + int(dist * shear)
                for k in range(2):
                    if get(out, nx + k, ny)[3] == 0:
                        put(out, nx + k, ny, color, alpha)
    return out


def glow(im, cx, cy, r, color="#ffce50", strength=0.6):
    """Pixel-art glow: dithered rings that fade out, blended over im."""
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
            if d >= 1:
                continue
            a = (1 - d) ** 1.6 * strength
            if dither(x, y, min(1.0, a * 1.8)):
                mix(im, x, y, color, min(0.85, a + 0.15))


def sparkle(im, x, y, size=3, color="#ffffff"):
    """Four-point star like the ones in the icon."""
    put(im, x, y, color)
    for k in range(1, size + 1):
        c = color if k < size else "#ffde96"
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            put(im, x + dx, y + dy, c)
