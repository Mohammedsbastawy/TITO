#!/usr/bin/env python3
"""Assemble a fake in-engine frame from the REAL chopped sprites.

Paste-only compositor (no drawn primitives): mirrors prologue_builder.gd's
placement math so the user can eyeball parallax layers + prop scale before
running Godot. Window: world x [-160..1460], y [-160..720].
"""
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
ENV = ROOT / "assets2d" / "sprites" / "env"
CHARS = ROOT / "assets2d" / "sprites" / "chars"
OUT = ROOT / "assets2d" / "mock_prologue_2d_v2.png"

WX0, WY0 = -160.0, -160.0
GROUND_Y = 600.0

canvas = Image.new("RGBA", (1620, 880), (10, 12, 24, 255))


def to_canvas(x: float, y: float) -> tuple[int, int]:
    return int(x - WX0), int(y - WY0)


def paste_scaled(name: str, scale: float, x: float, y: float,
                 mirror: float = 0.0, base: Path = ENV) -> None:
    im = Image.open(base / f"{name}.png").convert("RGBA")
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(im, to_canvas(x, y))
    if mirror > 0:
        n = 1
        while x + n * mirror < WX0 + canvas.width:
            canvas.alpha_composite(im, to_canvas(x + n * mirror, y))
            n += 1


def ground_prop(name: str, cx: float, target_h: float,
                ground: float = GROUND_Y, base: Path = ENV) -> None:
    im = Image.open(base / f"{name}.png").convert("RGBA")
    sc = target_h / im.height
    im = im.resize((max(1, int(im.width * sc)), max(1, int(target_h))), Image.LANCZOS)
    canvas.alpha_composite(im, to_canvas(cx - im.width * 0.5, ground - target_h))


# ---- parallax stack (prologue_builder._build_parallax values) ----
paste_scaled("night_sky", 2.4, -1600.0, -900.0, 3302.4)
for name, cx, cy, sc in (("cloud_1", -1500.0, -330.0, 1.5),
                         ("cloud_2", -450.0, -400.0, 1.15),
                         ("cloud_3", 350.0, -290.0, 1.7)):
    paste_scaled(name, sc, cx, cy)
paste_scaled("skyline_far", 1.6, -1600.0, -40.0, 3123.2)

# far block silhouettes: facades_d 0.72 tinted dark, bottoms at GROUND_Y
far = Image.open(ENV / "facades_d.png").convert("RGBA")
fw, fh = int(far.width * 0.72), int(far.height * 0.72)
far = far.resize((fw, fh), Image.LANCZOS)
dark = Image.new("RGBA", far.size, (117, 128, 184, 255))
far = ImageChops.multiply(far, dark)
canvas.alpha_composite(far, to_canvas(-1600.0, GROUND_Y - fh))
canvas.alpha_composite(far, to_canvas(-1600.0 + fw, GROUND_Y - fh))

# near endless facade band b+c+d at 0.95, bottoms at GROUND_Y
bx = -1600.0
for name in ("facades_b", "facades_c", "facades_d"):
    im = Image.open(ENV / f"{name}.png").convert("RGBA")
    nw, nh = int(im.width * 0.95), int(im.height * 0.95)
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas.alpha_composite(im, to_canvas(bx, GROUND_Y - nh))
    bx += nw

# ---- street strip tiles (_build_street) ----
ST = 0.82
strip = Image.open(ENV / "street_flat.png").convert("RGBA")
strip = strip.resize((int(strip.width * ST), int(strip.height * ST)), Image.LANCZOS)
for i in range(4):
    canvas.alpha_composite(strip, to_canvas(-96.0 + i * strip.width, GROUND_Y - 70.0 * ST))

# ---- zone props visible in the window (street zones 1-3) ----
for lx in (140.0, 640.0, 1160.0):
    ground_prop("lamp_post", lx + 7.0, 190.0)
ground_prop("shutter", 695.0, 118.0)
ground_prop("cafe_front", 942.0, 158.0)
ground_prop("cafe_front", 1190.0, 152.0)
ground_prop("sedan_dark", 1505.0, 82.0)
ground_prop("van", 1765.0, 96.0)

# ---- placeholder characters for scale ----
ground_prop("tito_idle", 760.0, 74.0, base=CHARS)
ground_prop("enforcer_idle", 1150.0, 76.0, base=CHARS)

# ---- night grade + downscale to 1408x768 ----
grade = Image.new("RGBA", canvas.size, (96, 110, 165, 70))
canvas = Image.alpha_composite(canvas, grade)
canvas.convert("RGB").resize((1408, 768), Image.LANCZOS).save(OUT)
print("wrote", OUT)
