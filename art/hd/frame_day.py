"""Cozy daytime variant of the target frame (Stardew-like mood, own world):
same layout as v4, natural daylight palette, warm brown outlines, blue sky
in the pond, no sunset grade. Run from art/: python3 -m hd.frame_day"""
import os

from PIL import Image, ImageChops, ImageFilter

from . import palette as P

DAY = {
    "grass": ["#24502e", "#2f6e34", "#3f8a38", "#5aa43c", "#7cbe48", "#a6d65a", "#d2ea7a"],
    "dust": ["#6a4a34", "#86603e", "#a07848", "#b89058", "#cca86c", "#dcc084", "#ead49c"],
    "soil": ["#3a2418", "#523222", "#6c4228", "#865632", "#a06c3e", "#b8844e"],
    "leaf": ["#1e4024", "#2a5a2e", "#3a7634", "#52943a", "#74b044", "#9cca54", "#c8e070"],
    "stone": ["#2e2a34", "#4a4450", "#66606a", "#827c86", "#a09aa2", "#bcb6bc", "#dcd6da"],
    "sky": ["#2e68a6", "#3a78b8", "#4a8ac4", "#62a0d2", "#82b8de", "#a2cce8", "#b8d8ec", "#c8e2f0"],
    "water": ["#1c3a6a", "#24508a", "#2e68a6", "#3e84bc", "#5aa2d2"],
    "cape": ["#2a1e30", "#3c2a48", "#523a62", "#6a4e7c", "#866a96", "#a488b0"],
    "dust_shadow": ["#000000"],
}
P.INK = "#3a2418"


def main():
    P.RAMPS.update(DAY)
    from . import draw
    draw.INK = "#3a2418"
    draw.outline.__defaults__ = ("#3a2418", True, 0.75)
    draw.cast_shadow.__defaults__ = (None, 0.55, 0.3, "#1c3418", 120)
    from . import frame as F
    from . import props as Pr
    F.COLORS.update({
        "#26163a": "#4a2c1c", "#34204c": "#5a3622", "#4a2f66": "#74482c", "#1a0f28": "#2e1a10",
        "#140818": "#1e100a", "#200f30": "#3a2214", "#e8d8f0": "#f0e0c8",
    })

    def extra(add):
        add(Pr.barrel(), 120, 186, ao=12)
        add(Pr.crate(), 136, 190, ao=16)
        add(Pr.mailbox(), 14, 216, ao=8)
        add(Pr.bush(26, 18, 2, berries="#ff4a6a"), 178, 214, ao=20)
        add(Pr.hay_bale(), 222, 362, ao=18)
        add(Pr.mushrooms(), 196, 180, shadow=False, ao=0)
        add(Pr.bench(), 104, 384, ao=24)
        add(Pr.log_pile(), 150, 196, ao=20)
        add(Pr.dog(0), 140, 386, ao=16)
        add(Pr.bush(30, 20, 3), 0, 446, ao=22)
        add(Pr.bush(24, 16, 4, berries="#5a8aff"), 196, 460, ao=18)
        add(Pr.mushrooms(), 30, 352, shadow=False, ao=0)

    F.EXTRA.append(extra)
    w = F.world()
    screen = w.resize((F.W * F.S, F.H * F.S), Image.NEAREST)
    canvas = Image.new("RGBA", (390 * F.K, 844 * F.K))
    canvas.alpha_composite(screen, (0, (844 * F.K - screen.height) // 2))
    base = canvas.convert("RGB")
    # soft daylight: tiny warm lift and gentle bloom, no dusk tint
    warm = Image.new("RGB", base.size, (14, 10, 0))
    base = ImageChops.add(base, warm)
    bright = base.point(lambda v: max(0, v - 225) * 2)
    base = ImageChops.add(base, bright.filter(ImageFilter.GaussianBlur(8)).point(lambda v: int(v * 0.4)))
    canvas = base.convert("RGBA")
    F.hud_parts(canvas)
    out = canvas.convert("RGB")
    out.save(os.path.join(F.ART, "target-day.png"))
    out.save("/mnt/project-files/stage1/target-frame-day.png")
    print("ok")


if __name__ == "__main__":
    main()
