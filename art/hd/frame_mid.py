"""Middle detail: full 32 px per tile, but flat colour bands instead of
dithering, plus a trimmed palette. Run from art/: python3 -m hd.frame_mid"""
import os

from PIL import Image, ImageFilter


def main():
    from . import palette as P
    P.dither = lambda x, y, t: t > 0.5  # flat bands, no checkerboard noise
    from . import frame_day as D
    from . import frame as F
    P.RAMPS.update(D.DAY)
    from . import draw
    draw.dither = P.dither
    draw.outline.__defaults__ = ("#3a2418", True, 0.75)
    draw.cast_shadow.__defaults__ = (None, 0.55, 0.3, "#1c3418", 120)
    F.COLORS.update({
        "#26163a": "#4a2c1c", "#34204c": "#5a3622", "#4a2f66": "#74482c", "#1a0f28": "#2e1a10",
        "#140818": "#1e100a", "#200f30": "#3a2214", "#e8d8f0": "#f0e0c8",
    })
    src = open(os.path.join(os.path.dirname(__file__), "frame_day.py")).read()
    ns = {}
    block = src[src.index("    def extra(add):"):src.index("    F.EXTRA.append(extra)")]
    exec("from hd import props as Pr\n" + "\n".join(l[4:] for l in block.splitlines()), ns)
    F.EXTRA.append(ns["extra"])
    w = F.world()
    a = w.getchannel("A")
    rgb = w.convert("RGB")
    # drop lone speckle pixels, keep edges: blend median back only where it differs little
    med = rgb.filter(ImageFilter.ModeFilter(3))
    q = med.quantize(colors=56, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(a)
    screen = q.resize((q.width * F.S, q.height * F.S), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * F.K, 844 * F.K))
    canvas.alpha_composite(screen, (0, (844 * F.K - screen.height) // 2))
    F.hud_parts(canvas)
    out = canvas.convert("RGB")
    out.save(os.path.join(F.ART, "target-mid.png"))
    out.save("/mnt/project-files/stage1/target-frame-mid.png")
    print("ok")


if __name__ == "__main__":
    main()
