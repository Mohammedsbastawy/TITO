#!/usr/bin/env python3
"""Assemble a fake in-engine frame from the REAL chopped env sprites.

Paste-only compositor (no drawn primitives): mirrors prologue_builder.gd's
placement math so the user can eyeball parallax + prop scale before running
Godot. Window: world x [-160..1460], y [-160..720].
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ENV = ROOT / "assets2d" / "sprites" / "env"
OUT = ROOT / "assets2d" / "mock_prologue_2d_v2.png"

WX0, WY0 = -160.0, -160.0  # world coords of canvas top-left
GROUND_Y = 600.0

canvas = Image.new("RGBA", (1620, 880), (10, 12, 24, 255))


def to_canvas(x: float, y: float) -> tuple[int, int]:
    return int(x - WX0), int(y - WY0)


def paste_scaled(name: str, scale: float, x: float, y: float, mirror: float = 0.0) -> None:
    im = Image.open(ENV / f"{name}.png").convert("RGBA")
    w, h = im.size
    im = im.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    canvas.alpha_composite(im, to_canvas(x, y))
    if mirror > 0:  # emulate ParallaxLayer.motion_mirroring copies
        n = 1
        while x + n * mirror < WX0 + canvas.width:
            canvas.alpha_composite(im, to_canvas(x + n * mirror, y))
            n += 1


def ground_prop(name: str, cx: float, target_h: float, ground: float = GROUND_Y) -> None:
    im = Image.open(ENV / f"{name}.png").convert("RGBA")
    w, h = im.size
    sc = target_h / h
    im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    canvas.alpha_composite(im, to_canvas(cx - im.width * 0.5, ground - target_h))


# ---- parallax stack (prologue_builder._build_parallax values) ----
paste_scaled("night_sky", 2.4, -1600.0, -900.0, 3302.4)
paste_scaled("skyline_far", 1.6, -1600.0, -40.0, 3123.2)
paste_scaled("facades_strip", 1.15, -1600.0, GROUND_Y - 618.0 * 1.15, 1582.4)

# ---- street strip tiles (_build_street) ----
ST, SW, STOP = 0.82, 1408.0 * 0.82, GROUND_Y - 70.0 * 0.82
strip = Image.open(ENV / "street_flat.png").convert("RGBA")
strip = strip.resize((int(strip.width * ST), int(strip.height * ST)), Image.LANCZOS)
for i in range(4):
    canvas.alpha_composite(strip, to_canvas(-96.0 + i * SW, STOP))

# ---- zone props visible in the window (street zones 1-3) ----
for lx in (140.0, 640.0, 1160.0):
    ground_prop("lamp_post", lx + 7.0, 190.0)
ground_prop("shutter", 695.0, 118.0)
ground_prop("cafe_front", 942.0, 158.0)
ground_prop("cafe_front", 1190.0, 152.0)
ground_prop("sedan_dark", 1505.0, 82.0)
ground_prop("van", 1765.0, 96.0)

# ---- night grade + downscale to 1408x768 ----
grade = Image.new("RGBA", canvas.size, (96, 110, 165, 70))
canvas = Image.alpha_composite(canvas, grade)
canvas.convert("RGB").resize((1408, 768), Image.LANCZOS).save(OUT)
print("wrote", OUT)
