"""Less detailed variant: the daytime world at half resolution (16 px per
tile, 3 pt per pixel), reduced palette. Run from art/: python3 -m hd.frame_low"""
import os

from PIL import Image


def main():
    from . import frame_day as D
    from . import frame as F
    from . import palette as P
    P.RAMPS.update(D.DAY)
    from . import draw
    draw.outline.__defaults__ = ("#3a2418", True, 0.75)
    draw.cast_shadow.__defaults__ = (None, 0.55, 0.3, "#1c3418", 120)
    F.COLORS.update({
        "#26163a": "#4a2c1c", "#34204c": "#5a3622", "#4a2f66": "#74482c", "#1a0f28": "#2e1a10",
        "#140818": "#1e100a", "#200f30": "#3a2214", "#e8d8f0": "#f0e0c8",
    })
    # reuse the day props
    src = open(os.path.join(os.path.dirname(__file__), "frame_day.py")).read()
    ns = {}
    block = src[src.index("    def extra(add):"):src.index("    F.EXTRA.append(extra)")]
    exec("from hd import props as Pr\n" + "\n".join(l[4:] for l in block.splitlines()), ns)
    F.EXTRA.append(ns["extra"])
    w = F.world()
    # half resolution: majority-ish colour per 2x2 block, then a 40-colour palette
    small = w.resize((w.width // 2, w.height // 2), Image.BOX)
    rgb = small.convert("RGB").quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    rgb.putalpha(small.getchannel("A"))
    screen = rgb.resize((rgb.width * 6, rgb.height * 6), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * F.K, 844 * F.K))
    canvas.alpha_composite(screen, (0, (844 * F.K - screen.height) // 2))
    F.hud_parts(canvas)
    out = canvas.convert("RGB")
    out.save(os.path.join(F.ART, "target-low.png"))
    out.save("/mnt/project-files/stage1/target-frame-low.png")
    print("ok")


if __name__ == "__main__":
    main()
