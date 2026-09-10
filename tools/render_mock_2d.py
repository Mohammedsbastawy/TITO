#!/usr/bin/env python3
"""PIL concept composite for the 2D prologue (NOT an engine render):
flat graphic-novel staging with the 7-layer parallax stack annotated."""
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(11)
W, H = 1680, 900
GY = 660          # street
RY = 330          # rooftop

img = Image.new('RGB', (W, H), (10, 13, 26))
dr = ImageDraw.Draw(img, 'RGBA')

# L1 sky + storm
for y in range(H):
    t = y / H
    dr.line([(0, y), (W, y)], fill=(int(16 * (1 - t) + 6 * t), int(20 * (1 - t) + 8 * t), int(38 * (1 - t) + 18 * t)))
pts = [(980, 0), (950, 80), (985, 150), (945, 240)]
dr.line(pts, fill=(200, 210, 255, 220), width=5, joint='curve')

# L2 far skyline
for i, x in enumerate(range(-30, W, 70)):
    h = 60 + (i * 53 % 110)
    dr.rectangle([x, 430 - h, x + 62, 470], fill=(16, 19, 34))
    for wy in range(400 - h, 430, 24):
        if (x + wy) % 4 == 0:
            dr.rectangle([x + 10, wy, x + 16, wy + 8], fill=(225, 180, 95, 130))
dr.rectangle([240, 300, 268, 430], fill=(13, 16, 29))  # minaret
dr.polygon([(232, 300), (276, 300), (254, 258)], fill=(13, 16, 29))

# L3 mid: brick walls + laundry lines
dr.rectangle([0, 360, 1180, 660], fill=(33, 29, 35))
for wy in range(368, 640, 18):
    off = 0 if (wy // 18) % 2 else 14
    for wx in range(-14 + off, 1180, 28):
        tone = 38 + (wx * 7 + wy) % 12
        dr.rectangle([wx, wy, wx + 24, wy + 13], fill=(tone, tone - 5, tone + 4))
for ly in (400, 440, 480):
    dr.arc([300, ly, 900, ly + 90], 200, 340, fill=(150, 155, 175, 200), width=3)
for cx in (430, 620, 760):
    lg = 400 + (cx % 80)
    dr.line([(cx, lg + 22), (cx, lg + 52)], fill=(190, 190, 205, 190), width=4)

# L4 near: cafe front + vintage cars
dr.rectangle([0, 520, 1180, 660], fill=(40, 34, 32))
for x in range(60, 1100, 240):
    dr.rectangle([x, 548, x + 120, 560], fill=(70, 30, 26))     # awning
    dr.rectangle([x + 10, 600, x + 100, 606], fill=(52, 40, 30))  # table
for (cx, col) in [(320, (30, 34, 48)), (760, (34, 30, 44))]:
    dr.rounded_rectangle([cx, 596, cx + 150, 648], 12, fill=col)
    dr.ellipse([cx + 16, 632, cx + 52, 656], fill=(12, 12, 16))
    dr.ellipse([cx + 98, 632, cx + 134, 656], fill=(12, 12, 16))
    for i in range(3):  # idle exhaust puffs
        dr.ellipse([cx - 14 - i * 10, 630 - i * 7, cx - 2 - i * 10, 642 - i * 7],
                   fill=(120, 124, 140, 60))

# L5 playable: street + canopy route + slide shutter + hero
dr.rectangle([0, 660, W, H], fill=(18, 20, 30))
for x in range(0, W, 46):
    dr.line([(x, 668), (x + 20, 668)], fill=(30, 33, 46), width=3)
dr.rectangle([540, 560, 660, 596], fill=(52, 56, 68))          # shutter bar
for wy in range(562, 594, 9):
    dr.line([(540, wy), (660, wy)], fill=(70, 76, 90), width=3)
dr.rectangle([540, 596, 660, 600], fill=(32, 34, 42))           # crawl slot
dr.rectangle([540, 600, 660, 606], fill=(210, 40, 30))
for cx in (880, 1010):                                          # canopies
    dr.rectangle([cx, 560, cx + 120, 570], fill=(64, 68, 84))
# smoke pocket over the lane
smoke = Image.new('L', (W, H), 0)
sd = ImageDraw.Draw(smoke)
for i in range(18):
    cx = 930 + random.randrange(-70, 220)
    cy = 640 - random.randrange(0, 60)
    rr = 30 + random.randrange(50)
    sd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=80)
smoke = smoke.filter(ImageFilter.GaussianBlur(24))
img.paste(Image.composite(Image.new('RGB', (W, H), (52, 56, 70)), img,
          smoke.point(lambda v: int(v * 0.6))), (0, 0))
dr = ImageDraw.Draw(img, 'RGBA')
# hero: mid-slide ink silhouette
hx, hy = 700, 660
dr.ellipse([hx - 30, hy - 26, hx - 6, hy - 2], fill=(26, 30, 44))
dr.rectangle([hx - 8, hy - 18, hx + 44, hy - 2], fill=(26, 30, 44))
dr.ellipse([hx + 34, hy - 20, hx + 52, hy - 4], fill=(222, 178, 140))
dr.rectangle([hx + 44, hy - 16, hx + 76, hy - 8], fill=(26, 30, 44))

# rooftop band (right) + girder + RAVEN
dr.rectangle([1180, 388, W, 420], fill=(28, 30, 40))
dr.rectangle([1260, 300, 1520, 312], fill=(70, 76, 98))
dr.line([(1270, 312), (1270, 388)], fill=(42, 44, 56), width=5)
dr.line([(1504, 312), (1504, 388)], fill=(42, 44, 56), width=5)
for i in range(5):  # sweep telegraph panels
    x0 = 1196 + i * 100
    dr.rectangle([x0, 356, x0 + 92, 388], fill=(255, 30, 30, 60))
    dr.rectangle([x0, 356, x0 + 92, 388], outline=(255, 70, 70, 170), width=3)
gx, gy = 1420, 388
dr.ellipse([gx - 44, gy - 162, gx + 44, gy - 52], fill=(7, 8, 13))
dr.rectangle([gx - 50, gy - 110, gx + 50, gy], fill=(7, 8, 13))
dr.ellipse([gx - 38, gy - 186, gx + 38, gy - 150], fill=(7, 8, 13))
dr.rectangle([gx - 20, gy - 206, gx + 20, gy - 172], fill=(7, 8, 13))
for ez in (-10, 10):
    dr.ellipse([gx + ez - 3, gy - 144, gx + ez + 3, gy - 137], fill=(255, 120, 30))

# L6 foreground occlusion: lamp posts + cables + wisps
for fx in (200, 1240):
    dr.rectangle([fx, 480, fx + 10, 660], fill=(8, 9, 14))
    dr.rectangle([fx - 16, 470, fx + 26, 484], fill=(255, 214, 140, 230))
    dr.polygon([(fx - 14, 484), (fx + 24, 484), (fx + 90, 660), (fx - 80, 660)],
               fill=(255, 210, 140, 22))
dr.arc([-200, 60, 900, 260], 20, 120, fill=(10, 11, 18), width=6)
dr.arc([500, 40, 1900, 240], 60, 165, fill=(10, 11, 18), width=6)

# rain veil
for i in range(700):
    x = random.randrange(W)
    y = random.randrange(H)
    dr.line([(x, y), (x + 3, y + 12)], fill=(170, 190, 235, 30), width=1)

# vignette + letterbox
vig = Image.new('L', (W, H), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-W * 0.25, -H * 0.3, W * 1.25, H * 1.3], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(img, Image.new('RGB', (W, H), (0, 0, 0)),
                      vig.point(lambda v: 255 - int((255 - v) * 0.5)))
dr = ImageDraw.Draw(img, 'RGBA')
dr.rectangle([0, 0, W, 60], fill=(0, 0, 0))
dr.rectangle([0, H - 64, W, H], fill=(0, 0, 0))

# title + layer key
dr.text((24, 20), 'PROLOGUE 2D - THE NIGHT IT ALL BEGAN', fill=(255, 210, 140))
dr.text((24, 42), 'neo-noir graphic novel * Mark of the Ninja staging * 7-layer parallax', fill=(150, 160, 205))
key = ' '.join(['L1 sky', 'L2 skyline', 'L3 brick+laundry', 'L4 cafe+cars',
                'L5 playable', 'L6 occlusion', 'L7 light+rain'])
dr.text((24, H - 46), key, fill=(140, 150, 190))
dr.text((24, H - 26), 'concept composite (PIL mock - not an engine render)', fill=(100, 106, 132))
for i, (lx, ly) in enumerate([(30, 90), (30, 130), (30, 180), (30, 545), (30, 690), (30, 480), (30, 740)]):
    pass  # layer tags kept in the key line

img.save('/home/user/TITO/assets2d/mock_prologue_2d.png')
print('wrote assets2d/mock_prologue_2d.png')
