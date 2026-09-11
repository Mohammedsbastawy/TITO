#!/usr/bin/env python3
"""Software render of levels2d/mansion/mansion_builder.gd (same coords/colors).
Full world canvas 0..4600 x, world y -900..720, then screenshot-style crops."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parent.parent
ENV = ROOT / "assets2d" / "sprites" / "env"
CHARS = ROOT / "assets2d" / "sprites" / "chars"
OUT = ROOT / "assets2d"

GY = 600.0
OY = 900  # canvas y offset
LIME = (159, 148, 128); STONE = (133, 128, 112); MARBLE = (209, 204, 189)
WOOD = (102, 69, 43); HEDGE = (36, 87, 48); LAWN = (41, 77, 51)
VAN = (76, 82, 97); GLASS = (140, 191, 230, 76)

canvas = Image.new("RGBA", (4600, 1620), (8, 10, 20, 255))


def W(x, y): return int(x), int(y + OY)

def rect(x0, y0, x1, y1, color):
    ImageDraw.Draw(canvas).rectangle([W(x0, y0), W(x1, y1)], fill=color)

def poly(pts, color):
    ImageDraw.Draw(canvas).polygon([W(px, py) for px, py in pts], fill=color)

def paste(name, scale, x, y, mirror=0.0, tint=None, base=ENV):
    im = Image.open(base / f"{name}.png").convert("RGBA")
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    if tint:
        im = ImageChops.multiply(im, Image.new("RGBA", im.size, tint))
    nx = x
    first = True
    while first or (mirror and nx < 4600):
        first = False
        if nx + im.width > 0:
            src_l = max(0, int(-nx)) if nx < 0 else 0
            dx = max(0, int(nx))
            part = im.crop((src_l, 0, im.width, im.height))
            canvas.alpha_composite(part, (dx, W(0, y)[1]))
        if not mirror:
            break
        nx += mirror

# ---- parallax at camera origin ----
paste("night_sky", 2.4, -1600.0, -900.0, 3302.4)
for n, cx, cy, sc in (("cloud_1", -1500.0, -330.0, 1.5), ("cloud_2", -450.0, -400.0, 1.15), ("cloud_3", 350.0, -290.0, 1.7)):
    paste(n, sc, cx, cy)
paste("skyline_far", 1.6, -1600.0, -40.0, 3123.2)
paste("facades_d", 1.5, -1600.0, 8.0, 1555.5, tint=(89, 97, 140, 255))

# ---- Z1 garden ----
rect(0, GY, 1560, 636, LAWN)
rect(420, 540, 510, 600, (56, 66, 76))
rect(480, 390, 502, 600, STONE)
for sx in (820, 1130):
    poly([(sx, 330), (sx + 64, 330), (sx + 150, 550), (sx - 70, 550)], (255, 242, 153, 34))
for hx in (700, 980):
    rect(hx, 504, hx + 130, 550, HEDGE)
    rect(hx - 6, 500, hx + 136, 512, (26, 61, 33))
rect(1180, 568, 1206, 600, MARBLE); rect(1314, 568, 1340, 600, MARBLE)
rect(1206, 588, 1314, 604, (89, 107, 128))
im = Image.open(ENV / "hose_reel.png").convert("RGBA"); sc = 44 / im.height
im = im.resize((int(im.width * sc), 44), Image.LANCZOS)
canvas.alpha_composite(im, W(int(1260 - im.width / 2), 560))
rect(1420, 420, 1462, 606, (76, 56, 33, 153))
for ry in range(424, 600, 22):
    rect(1422, ry, 1460, ry + 4, WOOD)
rect(1380, 420, 1570, 434, WOOD)

# ---- Z2 facade ----
rect(1560, 170, 1905, 230, LIME)

# ---- Z3 foyer ----
rect(2210, 170, 2214, 292, (153, 128, 64))
rect(2168, 290, 2256, 300, (168, 140, 71))
for i in range(4):
    x0 = 2450 + i * 45
    rect(x0, 600 - 55 * (i + 1), x0 + 45, 600, MARBLE)
rect(1750, 380, 4300, 396, LIME)
for wx in (1850, 2300, 2900, 3500, 4100):
    rect(wx - 5, 306, wx + 5, 316, (128, 102, 56))
rect(1560, 150, 4450, 170, (76, 71, 61))

# ---- Z4 locker ----
rect(2940, 316, 2984, 380, (51, 61, 77))
rect(2944, 324, 2976, 372, (87, 102, 122))

# ---- Z5 sunroom ----
for i in range(6):
    wx = 3120 + i * 120
    poly([(wx, 170), (wx + 90, 170), (wx + 90, 372), (wx, 372)], GLASS)
    rect(wx + 90, 170, wx + 98, 380, LIME)
rect(3340, 340, 3418, 380, MARBLE); rect(3560, 340, 3638, 380, MARBLE)
rect(3860, 230, 3882, 396, (128, 51, 51))

# ---- Z6 terrace ----
for bx in range(3880, 4280, 66):
    rect(bx, 300, bx + 10, 380, STONE)
rect(3880, 292, 4280, 302, STONE)
rect(4290, 640, 4450, 720, (13, 31, 61))

# ---- actors ----
tito = Image.open(CHARS / "anim" / "tito_idle" / "f_00.png").convert("RGBA")
t74 = tito.resize((int(tito.width * 74 / tito.height), 74), Image.LANCZOS)
for px, py in ((60, 600), (3260, 380)):
    canvas.alpha_composite(t74, W(px - t74.width // 2, py - 74))
enf_p = CHARS / "enforcer_idle.png"
if enf_p.exists():
    enf = Image.open(enf_p).convert("RGBA")
    e76 = enf.resize((int(enf.width * 76 / enf.height), 76), Image.LANCZOS)
    for px in (3450, 3660, 3760):
        canvas.alpha_composite(e76, W(px - e76.width // 2, 380 - 76))

# ---- night grade + glows ----
night = Image.new("RGBA", canvas.size, (102, 117, 168, 255))
canvas = ImageChops.multiply(canvas, night)
glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
LAMPS = [(850, 326, 110, (255, 242, 153)), (1160, 326, 110, (255, 242, 153)),
         (2212, 300, 130, (255, 204, 115)), (2962, 330, 90, (128, 230, 255)),
         (4220, 320, 110, (255, 191, 115))] + \
        [(wx, 300, 95, (255, 191, 102)) for wx in (1850, 2300, 2900, 3500, 4100)]
for x, y, r, c in LAMPS:
    for i in range(r, 0, -6):
        a = int(120 * (1 - i / r) ** 2)
        gd.ellipse([W(x - i, y - i), W(x + i, y + i)], fill=(c[0], c[1], c[2], a))
canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(8)))

# ---- crops ----
full = canvas.convert("RGB")
views = [
    (0, "view1_garden"),
    (1450, "view2_foyer_breach"),
    (2820, "view3_sunroom_ambush"),
    (3300, "view4_terrace_leap"),
]
for x0, name in views:
    crop = full.crop((x0, W(0, -60)[1], x0 + 1280, W(0, 660)[1]))
    crop.save(OUT / f"mock_mansion_{name}.png")
    print("wrote", name)
full.crop((0, W(0, -60)[1], 4600, W(0, 660)[1])).resize((1533, 240), Image.LANCZOS) \
    .save(OUT / "mock_mansion_overview.png")
print("wrote overview")
