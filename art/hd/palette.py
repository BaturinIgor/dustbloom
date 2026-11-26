"""Sunset palette taken from the app icon: purple ambient shadows, warm
orange key light, cream highlights. Every ramp runs dark -> light."""
import math

INK = "#1e101e"

RAMPS = {
    # living grass: teal-violet in shade, warm yellow-green in the sun
    "grass": ["#1f2a3e", "#1d4a46", "#2a6a44", "#4a8a3a", "#7aae3e", "#b8d25a", "#e8e88a"],
    # wasteland dust: the icon's mauve horizon
    "dust": ["#241638", "#3a1c40", "#50244c", "#6f4264", "#81476a", "#9a4f69", "#b25567"],
    "soil": ["#1e101e", "#3a1c2a", "#5a2a30", "#7a3e34", "#9a5a3c", "#b8784a"],
    "pumpkin": ["#501f18", "#7a2a18", "#b0421a", "#de6620", "#f68c2a", "#ffb652", "#ffde96"],
    "glow": ["#de6620", "#ff9628", "#ffce50", "#fff4a0", "#ffffff"],
    "straw": ["#3a1c28", "#784e28", "#a87638", "#d6a852", "#f0ce7a", "#ffe8a4"],
    "wood": ["#1e101e", "#3a1c2a", "#5f2e2e", "#784e28", "#a2683a", "#c88a4e"],
    "roof": ["#241638", "#50244c", "#842e5d", "#b0423e", "#e76648", "#f68c5a", "#ffb68a"],
    "stone": ["#1e101e", "#2c1e4a", "#422e68", "#5a4284", "#765ca0", "#967cbe", "#c2b0e0"],
    "wall": ["#3a1c28", "#784e28", "#a87638", "#d6a852", "#f0ce7a", "#ffe8a4"],
    "water": ["#140c2a", "#1e1a4a", "#2c2e6a", "#3e4e8e", "#5a74b0"],
    "sky": ["#2c1e4a", "#50244c", "#842e5d", "#b25567", "#e76648", "#f68c2a", "#ffb652", "#ffde96"],
    "leaf": ["#1f1a3e", "#1d3a46", "#2a5a44", "#3e7a3e", "#6a9e3a", "#a2c44a", "#d8e070"],
    "blossom": ["#842e5d", "#b25567", "#e76f8a", "#ff9fb0", "#ffd6dc"],
    "cloth_blue": ["#1e1a4a", "#2c2e6a", "#3e4e8e", "#5a74b0", "#8aa2d8"],
    "cloth_red": ["#3a1428", "#6a1e3a", "#a02e44", "#d24c4e", "#f27a6e"],
    "skin": ["#7a3e34", "#b8664a", "#e0946a", "#f6c094"],
    "cape": ["#1e101e", "#241638", "#3c194f", "#5a2a6e", "#765ca0", "#967cbe"],
    "white": ["#5f3d5d", "#9a7a9a", "#d8c8d8", "#fff4f0", "#ffffff"],
    "ui": ["#0f0818", "#1a0f28", "#26163a", "#34204c", "#4a2f66", "#6a4a8a"],
    "gold": ["#3a1c18", "#7a3a18", "#b8661e", "#f0a02e", "#ffce50", "#fff0a8"],
    "mint": ["#123a3a", "#1d6a4a", "#2f9a5a", "#5ac86a", "#a2ec8a"],
    "red": ["#4a0f22", "#8a1e30", "#d23a44", "#ff6a5e", "#ffb0a0"],
}


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(name, t):
    """Colour at t in 0..1 along a ramp (no blending: pixel art)."""
    r = RAMPS[name]
    i = max(0, min(len(r) - 1, int(t * len(r))))
    return r[i]


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y, t):
    return t * 16 > BAYER[int(y) % 4][int(x) % 4] + 0.5


def ramp_d(name, t, x, y, spread=1.0):
    """Ramp colour with ordered dithering between neighbouring bands."""
    r = RAMPS[name]
    v = max(0.0, min(0.9999, t)) * len(r)
    i = int(v)
    f = v - i
    if i < len(r) - 1 and dither(x, y, f * spread):
        i += 1
    return r[min(i, len(r) - 1)]


def noise2(x, y, seed=0, scale=8.0):
    """Cheap smooth value noise (bilinear over a hashed lattice), -1..1."""
    def h(ix, iy):
        n = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = h(ix, iy) + (h(ix + 1, iy) - h(ix, iy)) * tx
    b = h(ix, iy + 1) + (h(ix + 1, iy + 1) - h(ix, iy + 1)) * tx
    return a + (b - a) * ty


def fbm(x, y, seed=0, scale=16.0, octaves=3):
    v, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        v += noise2(x, y, seed + o * 17, scale / (2 ** o)) * amp
        tot += amp
        amp *= 0.5
    return v / tot


def hash01(x, y, seed=0):
    n = (int(x) * 73856093 ^ int(y) * 19349663 ^ seed * 83492791) & 0xFFFFFFFF
    n = (n * 2654435761) & 0xFFFFFFFF
    return (n >> 8 & 0xFFFF) / 65535.0
