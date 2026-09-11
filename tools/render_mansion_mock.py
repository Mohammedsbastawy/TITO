#!/usr/bin/env python3
"""Render mock views of the mansion prologue level (no Godot in sandbox).

Reads EXACT coordinates/colors from levels2d/mansion/mansion_builder.gd and now
stamps the REAL chopped kit sprites (assets2d/sprites/env) instead of flat
boxes. Exports the same four phone crops + an overview strip.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageChops
import os

A2 = "assets2d"
ENV = os.path.join(A2, "sprites/env")
WORLD_W = 4600
H = 1680
OY = 900  # world y -> canvas y = y - OY


def load(name):
    return Image.open(os.path.join(ENV, name + ".png")).convert("RGBA")


def tint(img, r, g, b):
    """Dim a sprite toward a night-ish tint (multiplicative)."""
    if (r, g, b) == (1, 1, 1):
        return img
    al = img.getchannel("A")
    rgb = img.convert("RGB")
    fac = Image.new("RGB", img.size, (int(r * 255), int(g * 255), int(b * 255)))
    out = ImageChops.multiply(rgb, fac).convert("RGBA")
    out.putalpha(al)
    return out


def stamp(cv, img, cx, base, h, z_tint=(1, 1, 1), flip=False):
    """Paste sprite centered at cx with its base at world-y `base`, height h."""
    if img is None:
        return
    w = int(img.width * (h / img.height))
    t = img.resize((max(w, 1), h), Image.LANCZOS)
    if flip:
        t = t.transpose(Image.FLIP_LEFT_RIGHT)
    t = tint(t, *z_tint)
    cv.paste(t, (int(cx - w / 2), int(base + OY - h)), t)


def stamp_xy(cv, img, x, top, w, h, z_tint=(1, 1, 1)):
    """Stretch sprite into absolute rect (world coords)."""
    t = img.resize((max(int(w), 1), max(int(h), 1)), Image.LANCZOS)
    t = tint(t, *z_tint)
    cv.paste(t, (int(x), int(top + OY)), t)


def rect(cv, x, y, w, h, col):
    d = ImageDraw.Draw(cv)
    d.rectangle([x, y + OY, x + w, y + OY + h], fill=col)


def main():
    cv = Image.new("RGBA", (WORLD_W, H))
    d = ImageDraw.Draw(cv)

    # ---- night sky gradient -------------------------------------------
    for y in range(H):
        t = y / H
        col = (int(10 + 22 * t), int(13 + 26 * t), int(30 + 40 * t))
        d.line([(0, y), (WORLD_W, y)], fill=col)
    # naive stars above the hall
    import random
    random.seed(7)
    for _ in range(160):
        sx, sy = random.uniform(0, WORLD_W), random.uniform(850, 1400)
        r = random.choice([1, 1, 1, 2])
        d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(180, 196, 235, 150))
    # big moon over the terrace side
    d.ellipse([3640, 905, 3820, 1085], fill=(228, 232, 244, 200))
    d.ellipse([3676, 937, 3836, 1097], fill=(10, 13, 32, 255))

    # ---- far skyline (parallax flavor) --------------------------------
    try:
        sky = load("skyline_far").resize((4200, 500), Image.LANCZOS)
        sky = tint(sky, 0.5, 0.52, 0.66)
        cv.paste(sky, (40, 1180), sky)
    except OSError:
        pass

    sprites = {}
    for n in ["wall_stone", "grass_strip", "trash_bin", "hedge_arch",
              "searchlight_pole", "fountain_dry", "trellis", "van_armored",
              "doors_mahogany", "column_tall", "chandelier", "stairs_marble",
              "rug_strip", "sconce", "locker_metal", "sideboard", "armchair",
              "plant_pot", "french_window", "table_flipped", "balustrade",
              "hose_reel", "facade_strip", "entrance_arch", "balcony",
              "window_shutter", "cornice", "carriage_lamp", "roofline",
              "iron_gate", "floor_planks"]:
        try:
            sprites[n] = load(n)
        except OSError:
            sprites[n] = None

    # ================= ZONE 1 : garden =================================
    rect(cv, 0, 600, 1560, 40, (22, 38, 24))
    for y in range(600, 640, 8):  # lawn micro gradient
        d.line([(0, y + OY), (1560, y + OY)],
               fill=(20 + (y - 600) // 8, 36 + (y - 600) // 6, 24))
    # boundary wall behind (night-dimmed) + its base shadow on the lawn
    import random as _rng
    w_rng = _rng.Random(4)
    for wi, wx in enumerate(range(30, 1560, 148)):
        dti = 0.3 + w_rng.random() * 0.12
        stamp(cv, sprites["wall_stone"], wx, 600, 100,
              (dti, dti + 0.02, dti + 0.16), flip=(wi % 2 == 1))
    rect(cv, 0, 594, 1560, 8, (10, 14, 12))
    # wild grass fringe along the lawn
    for gx in range(60, 1560, 195):
        stamp(cv, sprites["grass_strip"], gx, 602, 26)
    # trash container + the perimeter wall (wall-kick pillar)
    stamp(cv, sprites["trash_bin"], 465, 600, 92)
    rect(cv, 480, 452, 22, 148, (96, 94, 84))
    stamp(cv, sprites["wall_stone"], 491, 450, 62)  # coping cap on the pillar
    # sculpted hedge arches (crawl tunnel under)
    stamp(cv, sprites["hedge_arch"], 750, 600, 96)
    stamp(cv, sprites["hedge_arch"], 1030, 600, 96)
    # searchlights
    for sx in [820, 1130]:
        stamp(cv, sprites["searchlight_pole"], sx, 600, 122, (0.8, 0.82, 0.95))
        cone = Image.new("RGBA", (220, 260), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cone)
        cd.polygon([(80, 0), (144, 0), (210, 240), (0, 240)],
                   fill=(255, 244, 190, 46))
        cv.paste(cone, (sx - 60, 330 + OY), cone)
    # dry marble fountain (nudged into frame for the phone crop)
    stamp(cv, sprites["fountain_dry"], 1215, 600, 112)
    # trellis + garage roof
    stamp(cv, sprites["trellis"], 1441, 600, 186, (0.85, 0.85, 0.95))
    rect(cv, 1380, 420, 190, 14, (74, 52, 34))
    rect(cv, 1380, 434, 190, 5, (44, 30, 20))
    # the squad van already rolling in across the lawn (mock framing)
    stamp(cv, sprites["van_armored"], 1130, 610, 108, (1.0, 1.0, 1.12), flip=True)
    rect(cv, 1180, 592, 230, 7, (255, 200, 90, 110))  # headlight sweep on grass
    # iron gate thrown open + carriage lamp by the entry
    if sprites["iron_gate"] is not None:
        g = sprites["iron_gate"]
        gh = 170
        gw = int(g.width * (gh / g.height))
        gt = g.resize((gw, gh), Image.LANCZOS).rotate(12, expand=True,
                                                      fillcolor=(0, 0, 0, 0))
        cv.paste(gt, (int(1430 - gt.width / 2), int(600 + OY - gt.height)), gt)
    stamp(cv, sprites["carriage_lamp"], 1530, 600, 150)

    # ================= ZONE 3 : hall walls FIRST (backdrop) ============
    rect(cv, 1560, 170, 2990, 446, (33, 26, 19))     # warm wall
    rect(cv, 1560, 380, 2990, 236, (52, 42, 31))     # under-mezz hall
    rect(cv, 1560, 470, 2990, 6, (78, 62, 46))       # wainscot line
    rect(cv, 1560, 596, 2990, 20, (64, 52, 38))      # hall floor band

    # ================= ZONE 2 : facade + doors =========================
    rect(cv, 1560, 600, 350, 16, (52, 44, 34))       # foyer floor
    # upper story facade + roofline silhouette along the whole hall
    stamp_xy(cv, sprites["facade_strip"], 1560, 170, 345, 60)
    stamp_xy(cv, sprites["facade_strip"], 1905, 84, 2545, 64, (0.62, 0.62, 0.72))
    stamp_xy(cv, sprites["roofline"], 1560, 50, 2890, 42)
    # grand entry: doors inside their arch, balcony floating above
    stamp(cv, sprites["doors_mahogany"], 1568, 600, 188)
    stamp(cv, sprites["entrance_arch"], 1568, 600, 218)
    stamp(cv, sprites["balcony"], 1568, 392, 88)
    stamp(cv, sprites["column_tall"], 1686, 602, 452)

    # ================= ZONE 3 : hall ===================================
    # cornice crowning the hall walls + under-mezz detailing
    stamp_xy(cv, sprites["cornice"], 1560, 148, 2990, 22, (0.85, 0.85, 0.95))
    for cx in [2000, 2400, 2780]:
        stamp(cv, sprites["window_shutter"], cx, 604, 128, (0.9, 0.9, 1.0))
    stamp_xy(cv, sprites["floor_planks"], 1560, 602, 2990, 14, (1.0, 0.92, 0.8))
    rect(cv, 1750, 380, 2550, 16, (110, 102, 92))    # mezzanine slab
    rect(cv, 1750, 396, 2550, 6, (60, 55, 49))
    # red runner carpet
    for rx in range(1800, 2860, 132):
        stamp_xy(cv, sprites["rug_strip"], rx, 368, 130, 12)
    # chandelier + landing platform
    stamp(cv, sprites["chandelier"], 2212, 312, 162)
    rect(cv, 2168, 290, 88, 10, (168, 140, 71))
    # marble steps up
    stamp_xy(cv, sprites["stairs_marble"], 2450, 380, 182, 220)
    # sconces down the hall
    for wx in [1850, 2300, 2900, 3500, 4100]:
        stamp(cv, sprites["sconce"], wx, 324, 64)

    # ================= ZONE 4 : armory =================================
    stamp(cv, sprites["sideboard"], 2668, 380, 56)
    stamp(cv, sprites["armchair"], 2700, 380, 52)
    stamp(cv, sprites["locker_metal"], 2962, 380, 70)

    # ================= ZONE 5 : sunroom ambush =========================
    for cx in [2980, 3060]:
        stamp(cv, sprites["column_tall"], cx, 602, 452)
    stamp(cv, sprites["plant_pot"], 3080, 380, 62)
    for i in range(6):
        wx = 3120 + i * 120
        stamp(cv, sprites["french_window"], wx + 45, 372, 200, (0.9, 0.92, 1.05))
    for cx in [3379, 3599]:
        stamp(cv, sprites["table_flipped"], cx, 380, 64)
    stamp(cv, sprites["plant_pot"], 3820, 380, 62)
    rect(cv, 3860, 230, 22, 166, (128, 51, 51))      # exit barricade
    rect(cv, 3856, 230, 30, 10, (80, 32, 32))

    # ================= ZONE 6 : terrace ================================
    for bx in range(3880, 4280, 104):
        stamp(cv, sprites["balustrade"], bx + 52, 380, 88, (0.92, 0.95, 1.06))
    stamp(cv, sprites["plant_pot"], 3898, 380, 60)
    rect(cv, 4290, 640, 160, 80, (13, 31, 61))       # canal water
    d.line([(4290, 646 + OY), (4450, 646 + OY)], fill=(80, 120, 180, 200), width=2)

    # ================= characters ======================================
    try:
        tito = Image.open(os.path.join(A2, "sprites/chars/tito_idle.png")).convert("RGBA")
        th = 74
        tw = int(tito.width * (th / tito.height))
        ti = tito.resize((tw, th), Image.LANCZOS)
        cv.paste(ti, (60, 600 + OY - th), ti)
        cv.paste(ti, (2190, 290 + OY - th), ti)  # mid-parkour on the chandelier
    except OSError:
        pass
    try:
        enf = Image.open(os.path.join(A2, "sprites/chars/enforcer_idle.png")).convert("RGBA")
        eh = 76
        ew = int(enf.width * (eh / enf.height))
        sil = Image.new("RGBA", (ew, eh), (12, 14, 22, 255))
        ea = enf.resize((ew, eh), Image.LANCZOS).getchannel("A")
        sil.putalpha(ea)
        for px, py in [(3210, 380), (3430, 380), (3720, 380),
                       (1470, 600), (1518, 600), (1560, 600)]:
            cv.paste(sil, (px - ew // 2, py + OY - eh), sil)
    except OSError:
        pass

    # ================= night grade + lamp glows ========================
    grade = Image.new("RGB", cv.size, (102, 117, 168))
    cv = ImageChops.multiply(cv.convert("RGB"), grade).convert("RGBA")

    glow = Image.new("RGBA", cv.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    glows = [(850, 330, (255, 244, 200), 130), (1160, 330, (255, 244, 200), 130),
             (1530, 462, (255, 184, 90), 110),
             (2212, 300, (255, 204, 115), 190), (1850, 300, (255, 191, 102), 120),
             (2300, 300, (255, 191, 102), 120), (2900, 300, (255, 191, 102), 120),
             (3500, 300, (255, 191, 102), 120), (4100, 300, (255, 191, 102), 120),
             (2962, 330, (128, 230, 255), 90), (4220, 320, (255, 191, 115), 140)]
    for gx, gy, gc, gr in glows:
        gd.ellipse([gx - gr, gy + OY - gr, gx + gr, gy + OY + gr],
                   fill=gc + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    cv = Image.alpha_composite(cv.convert("RGBA"), glow)

    # ================= exports =========================================
    crops = {"view1": 0, "view2": 1450, "view3": 2820, "view4": 3300}
    out = {}
    for tag, x0 in crops.items():
        ytop = 900 if tag == "view4" else 840  # terrace view keeps the canal
        box = (x0, ytop, x0 + 1240, ytop + 720)
        v = cv.crop(box).convert("RGB")
        p = os.path.join(A2, f"mock_mansion_{tag}.png")
        v.save(p)
        out[tag] = p
    ov = cv.crop((0, 916, 4600, 1560)).resize((1533, 214), Image.LANCZOS).convert("RGB")
    ov.save(os.path.join(A2, "mock_mansion_overview.png"))
    print("ok:", ", ".join(out))

    # ---- single vertical phone composite ------------------------------
    pad = 16
    tb = 46
    W = 1280
    imgs = [Image.open(p).resize((W - 2 * pad, int((W - 2 * pad) * 720 / 1240)),
                                 Image.LANCZOS) for p in out.values()]
    ih = imgs[0].height
    H2 = 60 + 4 * (ih + tb + pad) + pad
    ph = Image.new("RGB", (W, H2), (10, 10, 14))
    pd = ImageDraw.Draw(ph)
    try:
        from PIL import ImageFont
        f = ImageFont.truetype("assets/fonts/DejaVuSans-Bold.ttf", 26)
        f2 = ImageFont.truetype("assets/fonts/DejaVuSans-Bold.ttf", 34)
    except Exception:
        f = f2 = None
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        ar = lambda s: get_display(arabic_reshaper.reshape(s))
    except Exception:
        ar = lambda s: s
    pd.text((W // 2, 18),
            ar("المرحلة ١ — قصر «المالك» · لقطات لعبة TITO بالفن الحقيقي"),
            anchor="ma", font=(f2 or ImageFont.load_default()), fill=(255, 214, 102))
    names = ["١. حديقة القصر (متاهة السياج)", "٢. المدخل + اقتحام الفرقة",
             "٣. الصالة + الدولاب", "٤. الشرفة والهروبة"]
    y = 60
    for i, im in enumerate(imgs):
        pd.rectangle([0, y, W, y + tb], fill=(18, 20, 30))
        pd.text((W // 2, y + tb // 2), ar(names[i]), anchor="mm",
                font=(f or ImageFont.load_default()), fill=(255, 214, 102))
        ph.paste(im, (pad, y + tb))
        y += ih + tb + pad
    ph.save(os.path.join(A2, "mansion_phone_all.png"), quality=90)
    print("ok: phone composite", ph.size)


if __name__ == "__main__":
    main()
