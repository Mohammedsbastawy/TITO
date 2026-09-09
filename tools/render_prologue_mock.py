#!/usr/bin/env python3
"""PIL concept composite of the PROLOGUE level (NOT an engine screenshot).
Side-scrolling panorama: alley + shutter crawl, smoke/canopy denial, the
barricade gate, then the storm-rooftop duel vs EL-GHORAB."""
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

random.seed(7)
W, H = 1920, 900
GROUND_Y = 690
ROOF_Y = 330


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new('RGB', (W, H))
dr = ImageDraw.Draw(img, 'RGBA')

# storm sky
for y in range(H):
    t = y / H
    dr.line([(0, y), (W, y)], fill=lerp((16, 22, 44), (5, 7, 16), t))

# lightning bloom, top-right third
bolt = Image.new('L', (W, H), 0)
bd = ImageDraw.Draw(bolt)
pts = [(1380, 0), (1350, 90), (1385, 150), (1340, 250), (1370, 330)]
for wdt in (14, 6, 2):
    bd.line(pts, fill=255, width=wdt, joint='curve')
bolt = bolt.filter(ImageFilter.GaussianBlur(6))
glow = Image.new('RGB', (W, H), (190, 200, 255))
img = Image.composite(
    Image.blend(img, glow, 0.55), img, bolt.point(lambda v: int(v * 0.85)))
dr = ImageDraw.Draw(img, 'RGBA')

# far skyline parallax band
for i, x in enumerate(range(-40, W, 60)):
    h = 90 + (i * 37 % 120)
    c = (14, 18, 34) if i % 3 else (11, 14, 28)
    dr.rectangle([x, GROUND_Y - 260 - h, x + 54, GROUND_Y - 20], fill=c)
    # sparse lit windows
    for wy in range(GROUND_Y - 250 - h + 12, GROUND_Y - 40, 26):
        for wx in range(x + 6, x + 48, 14):
            if (wx + wy) % 5 == 0:
                dr.rectangle([wx, wy, wx + 5, wy + 8], fill=(215, 170, 90, 150))

# minaret + dome silhouette
dr.rectangle([300, GROUND_Y - 470, 330, GROUND_Y - 250], fill=(10, 13, 26))
dr.polygon([(292, GROUND_Y - 470), (338, GROUND_Y - 470), (315, GROUND_Y - 520)],
           fill=(10, 13, 26))
dr.ellipse([430, GROUND_Y - 420, 540, GROUND_Y - 330], fill=(10, 13, 26))

# near brick walls (the alley plane)
def brick_wall(x0, y0, x1, y1):
    dr.rectangle([x0, y0, x1, y1], fill=(34, 30, 34))
    for wy in range(y0 + 6, y1 - 4, 16):
        off = 0 if (wy // 16) % 2 else 12
        for wx in range(x0 - 12 + off, x1, 24):
            tone = 40 + (wx * 7 + wy) % 14
            dr.rectangle([wx, wy, wx + 20, wy + 11], fill=(tone, tone - 6, tone))

brick_wall(0, GROUND_Y - 210, 960, GROUND_Y - 30)
# shutter (crawl gap beneath)
dr.rectangle([330, GROUND_Y - 130, 420, GROUND_Y - 8], fill=(52, 56, 66))
for wy in range(GROUND_Y - 126, GROUND_Y - 12, 10):
    dr.line([(330, wy), (420, wy)], fill=(70, 74, 86), width=4)
dr.rectangle([330, GROUND_Y - 8, 420, GROUND_Y], fill=(26, 28, 34))   # crawl slot
dr.rectangle([330, GROUND_Y - 12, 420, GROUND_Y - 6], fill=(200, 40, 30))  # warn strip

# siren glow (red/blue alternating pools)
for cx, col in [(120, (235, 40, 40)), (205, (60, 90, 240))]:
    for r_, a_ in [(46, 40), (26, 70)]:
        dr.ellipse([cx - r_, GROUND_Y - 170 - r_, cx + r_, GROUND_Y - 170 + r_],
                   fill=col + (a_,))
dr.rectangle([150, GROUND_Y - 210, 158, GROUND_Y - 150], fill=(20, 22, 30))

# wet asphalt with reflected pools
dr.rectangle([0, GROUND_Y, W, H], fill=(14, 15, 22))
for i in range(400):
    x = random.randrange(W)
    y = random.randrange(GROUND_Y, H)
    a = 12 + (x + y) % 18
    dr.point((x, y), fill=(120, 140, 180, a))
for cx, col in [(120, (235, 40, 40)), (205, (60, 90, 240))]:
    dr.ellipse([cx - 30, GROUND_Y + 6, cx + 30, GROUND_Y + 30], fill=col + (50,))

# --- mid: smoke cloud rolling along the street (canopy route above) ---
smoke = Image.new('L', (W, H), 0)
sd = ImageDraw.Draw(smoke)
for i in range(26):
    cx = 620 + random.randrange(-120, 260)
    cy = GROUND_Y - 30 - random.randrange(0, 90)
    rr = 40 + random.randrange(70)
    sd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=90)
smoke = smoke.filter(ImageFilter.GaussianBlur(30))
img = Image.composite(Image.new('RGB', (W, H), (46, 50, 62)), img,
                      smoke.point(lambda v: int(v * 0.7)))
dr = ImageDraw.Draw(img, 'RGBA')
# canopies above the smoke
for cx in (610, 760, 890):
    dr.rectangle([cx, GROUND_Y - 150, cx + 120, GROUND_Y - 140], fill=(60, 64, 78))
    dr.rectangle([cx + 4, GROUND_Y - 140, cx + 12, GROUND_Y - 40], fill=(30, 32, 40))
# tactical red sight-line
dr.line([(830, GROUND_Y - 105), (600, GROUND_Y - 60)], fill=(240, 30, 30, 200), width=2)

# --- the gate ---
dr.rectangle([960, GROUND_Y - 260, 1030, GROUND_Y], fill=(48, 52, 62))
for wy in range(GROUND_Y - 250, GROUND_Y, 26):
    dr.line([(960, wy), (1030, wy)], fill=(64, 68, 80), width=5)
for i in range(4):
    c = (210, 40, 30) if i % 2 == 0 else (230, 230, 235)
    dr.rectangle([962, GROUND_Y - 40 - i * 60, 1028, GROUND_Y - 20 - i * 60],
                 outline=c, width=6)
dr.ellipse([985, GROUND_Y - 290, 1005, GROUND_Y - 270], fill=(240, 40, 30))

# --- scaffold + rooftop duel plane ---
brick_wall(1150, ROOF_Y - 200, W, ROOF_Y + 40)
dr.rectangle([1060, ROOF_Y, W, ROOF_Y + 60], fill=(26, 28, 36))         # roof slab
for x in range(1060, W, 4):
    y = ROOF_Y + 2 + (x * 13 % 6)
    dr.line([(x, y), (x + 2, y)], fill=(40, 42, 52))
# girder
dr.rectangle([1250, ROOF_Y - 120, 1580, ROOF_Y - 106], fill=(70, 76, 96))
for x in range(1255, 1580, 40):
    dr.rectangle([x, ROOF_Y - 106, x + 4, ROOF_Y], fill=(40, 42, 54))
# floodlight cones
for fx in (1130, 1720):
    dr.rectangle([fx - 4, ROOF_Y - 190, fx + 4, ROOF_Y], fill=(24, 26, 34))
    dr.rectangle([fx - 20, ROOF_Y - 200, fx + 20, ROOF_Y - 184], fill=(255, 220, 150))
    dr.polygon([(fx - 18, ROOF_Y - 184), (fx + 18, ROOF_Y - 184),
                (fx + 90, ROOF_Y), (fx - 90, ROOF_Y)], fill=(255, 215, 140, 26))
# sweep telegraph: red floor grid panels
for i in range(6):
    x0 = 1160 + i * 105
    dr.rectangle([x0, ROOF_Y - 40, x0 + 100, ROOF_Y], fill=(255, 30, 30, 55))
    dr.rectangle([x0, ROOF_Y - 40, x0 + 100, ROOF_Y], outline=(255, 60, 60, 160), width=3)

# EL-GHORAB silhouette: broad coat, wide-brim hat, ember eyes
gx, gy = 1560, ROOF_Y
dr.ellipse([gx - 46, gy - 190, gx + 46, gy - 60], fill=(8, 9, 14))      # shoulders
dr.rectangle([gx - 52, gy - 130, gx + 52, gy], fill=(8, 9, 14))         # coat
dr.ellipse([gx - 40, gy - 216, gx + 40, gy - 176], fill=(8, 9, 14))     # hat brim
dr.rectangle([gx - 22, gy - 238, gx + 22, gy - 200], fill=(8, 9, 14))   # crown
for ez in (-12, 12):
    dr.ellipse([gx + ez - 4, gy - 168, gx + ez + 4, gy - 160], fill=(255, 120, 30))
# his low shot tracer
dr.line([(gx - 60, gy - 40), (gx - 400, gy - 40)], fill=(255, 140, 50, 220), width=3)

# TITO mid-leap over the tracer, soaked jacket
tx, ty = 1130, ROOF_Y - 90
dr.ellipse([tx - 14, ty - 54, tx + 14, ty - 26], fill=(30, 30, 40))
dr.rectangle([tx - 16, ty - 28, tx + 12, ty + 12], fill=(120, 40, 36))
dr.line([(tx - 8, ty + 12), (tx + 16, ty + 30)], fill=(30, 30, 40), width=8)
dr.line([(tx + 4, ty + 12), (tx - 20, ty + 34)], fill=(30, 30, 40), width=8)
dr.ellipse([tx - 12, ty - 78, tx + 10, ty - 56], fill=(222, 178, 140))

# rain sheet
for i in range(900):
    x = random.randrange(W)
    y = random.randrange(H)
    ln = 10 + (i % 14)
    a = 26 + (i * 7) % 40
    dr.line([(x, y), (x + 4, y + ln)], fill=(170, 190, 235, a), width=1)

# vignette
vig = Image.new('L', (W, H), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-W * 0.25, -H * 0.25, W * 1.25, H * 1.25], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(img, Image.new('RGB', (W, H), (0, 0, 0)),
                      vig.point(lambda v: 255 - int((255 - v) * 0.55)))
dr = ImageDraw.Draw(img, 'RGBA')

# title block
dr.rectangle([0, H - 110, 620, H], fill=(0, 0, 0, 170))
dr.text((30, H - 96), 'PROLOGUE - THE NIGHT IT ALL BEGAN', fill=(255, 210, 140))
dr.text((30, H - 62), 'alley crawl  * smoke denial  * barricade breach  * EL-GHORAB on the roof',
        fill=(170, 180, 220))
dr.text((30, H - 36), 'concept composite (PIL mock — not an engine render)',
        fill=(110, 115, 140))

img.save('/home/user/TITO/assets/textures/prologue_mock.png')
print('wrote assets/textures/prologue_mock.png')
