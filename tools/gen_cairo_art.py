#!/usr/bin/env python3
## Generates the hand-tailored layered art for the "Downtown Cairo at night"
## level: flat painterly parallax silhouettes (far Citadel/minaret skyline,
## mid rooftop jungle), tiling street + sidewalk strips, glowing Arabic neon
## shop signs, and foreground palm fronds. All deterministic (seeded).
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "/home/user/TITO/assets/textures/cairo"
FONTS = "/home/user/TITO/assets/fonts"
rng = random.Random(20260910)

# palette (Prince-of-Persia-ish night grade: indigo/teal + amber warmth)
FAR_TOP = (0x24, 0x2a, 0x50, 255)
FAR_BOT = (0x33, 0x46, 0x71, 255)
MID_TOP = (0x14, 0x18, 0x2e, 255)
MID_BOT = (0x1f, 0x27, 0x4a, 255)
WIN_HOT = (255, 198, 116, 255)
WIN_DIM = (222, 148, 84, 235)
ANT_RED = (255, 70, 90, 255)


def vgrad(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        for x in range(w):
            px[x, y] = c
    return img


def minaret(d, x, base_y, h, col):
    w = max(h // 16, 8)
    d.rectangle([x - w, base_y - int(h * 0.62), x + w, base_y], fill=col)          # shaft
    ring_w = int(w * 1.9)
    d.rectangle([x - ring_w, base_y - int(h * 0.66), x + ring_w,
                 base_y - int(h * 0.62)], fill=col)                                  # balcony ring
    d.rectangle([x - w * 3 // 4, base_y - int(h * 0.85), x + w * 3 // 4,
                 base_y - int(h * 0.66)], fill=col)                                  # upper shaft
    d.polygon([(x - w, base_y - int(h * 0.85)), (x + w, base_y - int(h * 0.85)),
               (x, base_y - h)], fill=col)                                           # cone
    d.ellipse([x - 3, base_y - h - 7, x + 3, base_y - h + 2], fill=col)              # finial bead
    # lit gallery slit
    d.rectangle([x - 1, base_y - int(h * 0.52), x + 1, base_y - int(h * 0.40)],
                fill=(255, 214, 140, 220))


def dome(d, x, base_y, r, col):
    d.pieslice([x - r, base_y - 2 * r, x + r, base_y], 180, 360, fill=col)
    d.rectangle([x - r // 6, base_y - 2 * r - 8, x + r // 6, base_y - 2 * r], fill=col)
    d.ellipse([x - 3, base_y - 2 * r - 14, x + 3, base_y - 2 * r - 8], fill=col)


def crenellations(d, x0, x1, y, step, size, col):
    x = x0
    while x + size <= x1:
        d.rectangle([x, y - size, x + size, y], fill=col)
        x += step


def _band_fade(img, y0, y1):
    """alpha = 0 above y0, ramps to full at y1 (top-freed haze band)."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        t = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        a = int(255 * t)
        for x in range(w):
            r, g, b, old = px[x, y]
            px[x, y] = (r, g, b, min(old, a))
    return img


def gen_far_skyline():
    W, H = 4096, 768
    # haze band (bottom only, top freed) + opaque silhouettes composited over
    haze = _band_fade(vgrad((W, H), FAR_TOP, FAR_BOT), 300, 470)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(haze)
    img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 0)))
    sil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sil)
    ground = H  # silhouettes anchored to the bottom edge
    # one long city block of varying masses
    x = -40
    while x < W + 80:
        w = rng.randint(150, 330)
        h = rng.randint(170, 330)
        col = FAR_TOP if rng.random() < 0.5 else (0x28, 0x30, 0x58, 255)
        d.rectangle([x, ground - h, x + w, ground], fill=col)
        # parapet + occasional little dome/water tank clusters on the roof
        if rng.random() < 0.5:
            dome(d, x + rng.randint(30, max(31, w - 30)), ground - h,
                 rng.randint(26, 44), col)
        if rng.random() < 0.6:
            minaret(d, x + rng.randint(20, max(21, w - 20)), ground - h,
                    rng.randint(220, 340), col)
        x += w + rng.randint(18, 60)
    # The Citadel hill + Muhammad Ali mosque silhouette (the Cairo postmark)
    cx = int(W * 0.62)
    hill_w, hill_h = 900, 190
    d.pieslice([cx - hill_w // 2, ground - hill_h - 120, cx + hill_w // 2,
                ground + 300], 180, 360, fill=(0x2b, 0x33, 0x5c, 255))
    plateau = ground - hill_h - 40
    d.rectangle([cx - 340, plateau, cx + 340, ground], fill=(0x2b, 0x33, 0x5c, 255))
    d.rectangle([cx - 170, plateau - 120, cx + 170, plateau], fill=FAR_TOP)
    crenellations(d, cx - 170, cx + 170, plateau - 120, 34, 16, FAR_TOP)
    dome(d, cx - 55, plateau - 120, 62, FAR_TOP)
    dome(d, cx + 55, plateau - 120, 62, FAR_TOP)
    dome(d, cx, plateau - 120, 88, FAR_TOP)
    minaret(d, cx - 190, plateau - 118, 330, FAR_TOP)
    minaret(d, cx + 190, plateau - 118, 330, FAR_TOP)
    # sparse windows + radio-tower blinks
    for _ in range(240):
        wx, wy = rng.randint(0, W - 3), rng.randint(H - 330, H - 24)
        wx -= wx % 3
        d.point([(wx, wy), (wx, wy + 1)], fill=WIN_DIM if rng.random() < 0.6 else WIN_HOT)
    for tx in [int(W * 0.18), int(W * 0.83)]:
        d.line([tx, H - 470, tx, H - 250], fill=FAR_TOP, width=5)
        d.ellipse([tx - 4, H - 478, tx + 4, H - 470], fill=ANT_RED)
    img.alpha_composite(sil)
    img.save(f"{OUT}/skyline_far.png", optimize=True)


def gen_mid_skyline():
    W, H = 4096, 896
    haze = _band_fade(vgrad((W, H), MID_TOP, MID_BOT), 250, 430)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(haze)
    si = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(si)
    ground = H
    x = -30
    while x < W + 60:
        w = rng.randint(210, 380)
        h = rng.randint(300, 560)
        col = MID_TOP if rng.random() < 0.6 else (0x18, 0x1e, 0x38, 255)
        top = ground - h
        d.rectangle([x, top, x + w, ground], fill=col)
        # brightened roof lip (catches the moonlight)
        d.rectangle([x, top, x + w, top + 5], fill=(0x37, 0x41, 0x6d, 255))
        # roof clutter: water tanks, AC boxes, dishes, antennas
        for _ in range(rng.randint(2, 5)):
            tx = rng.randint(x + 12, max(x + 13, x + w - 40))
            kind = rng.randint(0, 3)
            if kind == 0:  # water tank (cylinder)
                tw, th = rng.randint(28, 46), rng.randint(30, 52)
                d.rectangle([tx, top - th, tx + tw, top], fill=col)
                d.ellipse([tx, top - th - 8, tx + tw, top - th + 8], fill=col)
            elif kind == 1:  # AC box
                bw, bh = rng.randint(26, 44), rng.randint(18, 30)
                d.rectangle([tx, top - bh, tx + bw, top], fill=(0x10, 0x14, 0x28, 255))
            elif kind == 2:  # satellite dish
                rr = rng.randint(14, 22)
                d.pieslice([tx - rr, top - rr - 22, tx + rr, top + rr - 22],
                           200, 320, fill=(0x10, 0x14, 0x28, 255))
                d.line([tx, top - 22, tx + rr // 2, top - rr - 22],
                       fill=(0x10, 0x14, 0x28, 255), width=3)
            else:  # antenna with red blink
                ah = rng.randint(40, 90)
                d.line([tx, top, tx, top - ah], fill=(0x10, 0x14, 0x28, 255), width=4)
                if rng.random() < 0.5:
                    d.ellipse([tx - 3, top - ah - 6, tx + 3, top - ah], fill=ANT_RED)
        # window grid, sparse warm lit ones
        cell_w, cell_h = 34, 42
        for gy in range(top + 26, ground - 6, cell_h):
            for gx in range(x + 12, x + w - 16, cell_w):
                if rng.random() < 0.16:
                    c = WIN_HOT if rng.random() < 0.45 else WIN_DIM
                    d.rectangle([gx, gy, gx + 12, gy + 18], fill=c)
                elif rng.random() < 0.4:
                    d.rectangle([gx, gy, gx + 12, gy + 18], fill=(0x0d, 0x11, 0x22, 255))
        x += w + rng.randint(30, 80)
    img.alpha_composite(si)
    img.save(f"{OUT}/skyline_mid.png", optimize=True)


def gen_street():
    W, H = 1024, 256
    img = Image.new("RGBA", (W, H), (20, 22, 33, 255))
    d = ImageDraw.Draw(img)
    px = img.load()
    for i in range(14000):  # asphalt grain
        xx, yy = rng.randrange(W), rng.randrange(H)
        v = rng.randint(-10, 14)
        r, g, b, a = px[xx, yy]
        px[xx, yy] = (max(0, min(255, r + v)), max(0, min(255, g + v)),
                      max(0, min(255, b + int(v * 1.2))), 255)
    # faint center lane dashes (worn paint)
    for x0 in range(0, W, 84):
        d.rectangle([x0, H - 42, x0 + 44, H - 38], fill=(92, 92, 84, 90))
    # gutter grime along bottom
    d.rectangle([0, H - 16, W, H], fill=(14, 15, 24, 255))
    img.save(f"{OUT}/street_top.png", optimize=True)

    W, H = 1024, 128
    img = Image.new("RGBA", (W, H), (43, 47, 64, 255))
    d = ImageDraw.Draw(img)
    for x0 in range(0, W, 128):  # paving slabs
        d.line([x0, 0, x0, H], fill=(24, 26, 38, 255), width=3)
    d.line([0, 8, W, 8], fill=(60, 66, 90, 255), width=4)       # curb highlight
    d.line([0, 14, W, 14], fill=(24, 26, 38, 255), width=2)
    for i in range(450):  # speckle
        xx, yy = rng.randrange(W), rng.randrange(H)
        d.point([(xx, yy)], fill=(60 + rng.randint(-12, 20),) * 3 + (120,))
    img.save(f"{OUT}/sidewalk.png", optimize=True)


def neon(prefix, text, glow, size, canvas=(1152, 384), plaque=True):
    W, H = canvas
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if plaque:
        d.rounded_rectangle([18, 18, W - 18, H - 18], radius=28,
                            fill=(12, 14, 25, 235), outline=(45, 51, 80, 255), width=5)
    font = ImageFont.truetype(f"{FONTS}/DejaVuSans-Bold.ttf", size)
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        shown = get_display(arabic_reshaper.reshape(text))
    except Exception:
        shown = text
    # thick neon tube in the glow color, blurred into halos behind the core
    tube = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(tube).text((W // 2, H // 2), shown, font=font, anchor="mm",
                              fill=glow + (255,), stroke_width=14,
                              stroke_fill=glow + (255,))
    for rad, alpha in [(34, 130), (18, 120), (8, 110)]:
        img.alpha_composite(tube.filter(ImageFilter.GaussianBlur(rad))
                            .point(lambda p, a=alpha: p * a // 255))
    img.alpha_composite(tube)
    # hot cream core
    ImageDraw.Draw(img).text((W // 2, H // 2), shown, font=font, anchor="mm",
                             fill=(255, 246, 224, 255), stroke_width=2,
                             stroke_fill=(255, 240, 210, 255))
    img.save(f"{OUT}/{prefix}.png", optimize=True)


def gen_signs():
    neon("sign_qahwa", "قهوة", (255, 170, 60), 210)                    # amber cafe
    neon("sign_radio", "راديو", (255, 70, 180), 200)                   # magenta radio
    neon("sign_funduq", "فندق كوزموبوليتان", (90, 200, 255), 110, canvas=(1536, 320))
    # METRO cinema marquee: deco plaque + bulb rows + latin + arabic
    W, H = 1280, 460
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([16, 16, W - 16, H - 16], radius=26,
                        fill=(24, 16, 34, 250), outline=(255, 196, 116, 255), width=6)
    for yy in (44, H - 44):  # bulb strips
        for x0 in range(48, W - 40, 56):
            d.ellipse([x0 - 8, yy - 8, x0 + 8, yy + 8], fill=(255, 226, 150, 255))
            d.ellipse([x0 - 3, yy - 3, x0 + 3, yy + 3], fill=(255, 255, 240, 255))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    big = ImageFont.truetype(f"{FONTS}/DejaVuSans-Bold.ttf", 190)
    ImageDraw.Draw(layer).text((W // 2, H // 2 - 26), "METRO", font=big, anchor="mm",
                               fill=(255, 90, 60, 255))
    for rad, alpha in [(24, 110), (12, 90)]:
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(rad))
                            .point(lambda p, a=alpha: p * a // 255))
    img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 0)))
    ImageDraw.Draw(img).text((W // 2, H // 2 - 26), "METRO", font=big, anchor="mm",
                             fill=(255, 244, 230, 255))
    small = ImageFont.truetype(f"{FONTS}/DejaVuSans-Bold.ttf", 84)
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        sub = get_display(arabic_reshaper.reshape("سينما"))
    except Exception:
        sub = "CINEMA"
    ImageDraw.Draw(img).text((W // 2, H - 90), sub, font=small, anchor="mm",
                             fill=(255, 196, 116, 255))
    img.save(f"{OUT}/sign_metro.png", optimize=True)


def gen_palm():
    S = 1024
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    origin = (S + 40, 120)  # fronds burst from off the top-right corner
    col = (9, 11, 20, 240)
    for i in range(9):
        ang = math.radians(150 + i * 16)
        length = 620 + rng.randint(-90, 130)
        droop = 130 + rng.randint(0, 90)
        ox, oy = origin
        mid = (ox + math.cos(ang) * length * 0.55, oy + math.sin(ang) * length * 0.40)
        tip = (ox + math.cos(ang) * length, oy + math.sin(ang) * length * 0.62 + droop)
        pts = []
        for t in [k / 24 for k in range(25)]:
            x = (1 - t) ** 2 * ox + 2 * (1 - t) * t * mid[0] + t ** 2 * tip[0]
            y = (1 - t) ** 2 * oy + 2 * (1 - t) * t * mid[1] + t ** 2 * tip[1]
            pts.append((x, y))
        d.line(pts, fill=col, width=10, joint="curve")
        # leaflets hanging off the curve
        for j, (x, y) in enumerate(pts[4::2]):
            ll = max(26, 74 - j * 3)
            d.line([(x, y), (x - 14, y + ll)], fill=col, width=5)
            d.line([(x, y), (x + 14, y + ll)], fill=col, width=5)
    img.save(f"{OUT}/palm_frond.png", optimize=True)


if __name__ == "__main__":
    gen_far_skyline()
    gen_mid_skyline()
    gen_street()
    gen_signs()
    gen_palm()
    print("cairo art done")
