#!/usr/bin/env python3
## Renders a concept mock of the cairo_night level using the REAL assets and
## REAL layout numbers from the builder (not the engine's output): camera at
## the cafe/cinema stretch of the street. For art-direction review only.
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import sys

T = "/home/user/TITO/assets/textures/cairo"
W, H = 1280, 720
S = float(sys.argv[2]) if len(sys.argv) > 2 else 46.0
CAM_X = float(sys.argv[1]) if len(sys.argv) > 1 else 33.0
CAM_Y = 1.5              # matches the in-game camera rig
GROUND_SCREEN = 672

def w2x(wx):
    return (wx - CAM_X) * S + W / 2

def w2y(wy):
    return GROUND_SCREEN - (wy) * S

def layer_x(base_x, stick, cam_x):
    return base_x + cam_x * stick

img = Image.new("RGB", (W, H), (10, 12, 29))

def paste_quad(tex, center_wx, center_wy, w_m, h_m, wrapper_base, wrapper_stick, flip=False, alpha=True):
    lx = layer_x(wrapper_base[0], wrapper_stick, CAM_X) + center_wx
    ly = wrapper_base[1] + center_wy
    px, py = w2x(lx), w2y(ly)
    tw, th = int(w_m * S), int(h_m * S)
    t = tex.resize((tw, th), Image.LANCZOS)
    if flip:
        t = t.transpose(Image.FLIP_LEFT_RIGHT)
    img.paste(t, (int(px - tw / 2), int(py - th / 2)), t if alpha else None)

sky = Image.open(f"{T}/sky.png").convert("RGBA")
far = Image.open(f"{T}/skyline_far.png").convert("RGBA")
mid = Image.open(f"{T}/skyline_mid.png").convert("RGBA")
facade = Image.open(f"{T}/facade_hero.png").convert("RGBA")
qahwa = Image.open(f"{T}/sign_qahwa.png").convert("RGBA")
metro = Image.open(f"{T}/sign_metro.png").convert("RGBA")
street = Image.open(f"{T}/street_top.png").convert("RGBA")
sidewalk = Image.open(f"{T}/sidewalk.png").convert("RGBA")

paste_quad(sky, 0, 0, 230, 118, (55, 40), 0.93)
paste_quad(far, -80, 0, 170, 31.9, (55, 13.9), 0.72)
paste_quad(far, 80, 0, 170, 31.9, (55, 13.9), 0.72, flip=True)
paste_quad(mid, -61, 0, 130, 28.4, (55, 12.2), 0.50)
paste_quad(mid, 61, 0, 130, 28.4, (55, 12.2), 0.50, flip=True)

d = ImageDraw.Draw(img, "RGBA")

def box(x0, x1, top, depth_to, color, roof_color=None):
    """draw a building slab: front face + thin roof lip"""
    d.rectangle([w2x(x0), min(w2y(top), w2y(depth_to)),
                 w2x(x1), max(w2y(top), w2y(depth_to))], fill=color)
    if roof_color:
        d.rectangle([w2x(x0), w2y(top) - 3, w2x(x1), w2y(top)], fill=roof_color)

# backdrop facades behind the shops (plaza row)
for i in range(3):
    paste_quad(facade, -3.5 + i * 7.0, 2.4 + 3.025, 7.0, 6.05, (0, 0), 0.0)

# shop strip + shops row A (walkable)
box(-8, 20, 2.4, -2, (28, 32, 51, 255), (58, 66, 96, 255))
box(22.6, 44.0, 2.4, 0, (22, 25, 42, 255))
box(26.0, 40.0, 2.4, -2, (30, 34, 54, 255), (60, 68, 100, 255))

# street + sidewalk + road band
def tile(tex, x0, x1, top, h_m, tile_w_m):
    tw = int(tile_w_m * S)
    t = tex.resize((tw, max(1, int(h_m * S))), Image.LANCZOS)
    zpos = w2x(x0)
    while zpos < w2x(x1):
        img.paste(t, (int(zpos), int(w2y(top))), None if t.mode != "RGBA" else t)
        zpos += tw
for run in [[-8, 20], [22.6, 56.6]]:
    tile(street, *run, 0.3, 1.1, 4.0)
    tile(sidewalk, run[0], run[1], 0.02, 0.12, 4.0)

# awnings
for ax in [25.0, 31.0, 37.0]:
    d.rectangle([w2x(ax), w2y(2.05) - int(.22 * S), w2x(ax + 2.2), w2y(2.05)],
                fill=(46, 50, 74, 255))
# plank + kiosk
d.rectangle([w2x(17.0), w2y(1.2) - int(.35 * S), w2x(18.3), w2y(1.2)], fill=(40, 44, 66, 255))
d.rectangle([w2x(22.9), w2y(2.4) - int(.25 * S), w2x(23.9), w2y(2.4)], fill=(46, 50, 74, 255))

# signs
paste_quad(qahwa, 28.0, 3.05, 4.4, 1.38, (0, 0), 0.0)
# cinema block + marquee
box(44.0, 58.0, 5.4, -2, (26, 29, 48, 255), (58, 66, 96, 255))
paste_quad(metro, 47.0, 4.35, 6.2, 2.23, (0, 0), 0.0)
d.rectangle([w2x(42.8), w2y(3.7) - int(.3 * S), w2x(45.2), w2y(3.7)], fill=(46, 50, 74, 255))

# street lamps with glow pools
for lx, real in [(18.0, 0), (30.0, 1), (40.5, 0), (52.0, 1)]:
    d.line([w2x(lx), w2y(0), w2x(lx), w2y(4.6)], fill=(16, 18, 30, 255), width=4)
    d.line([w2x(lx), w2y(4.6), w2x(lx + 0.9), w2y(4.62)], fill=(16, 18, 30, 255), width=3)
    hx, hy = w2x(lx + 0.9), w2y(4.45)
    if real:
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([hx - 130, hy - 130, hx + 130, hy + 130], fill=(255, 178, 92, 60))
        gd.ellipse([hx - 60, hy - 60, hx + 60, hy + 60], fill=(255, 196, 116, 90))
        gimg = img.convert("RGBA"); gimg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30)))
        img = gimg.convert("RGB"); d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([hx - 6, hy - 6, hx + 6, hy + 6], fill=(255, 220, 150, 255))

# pit
d.rectangle([w2x(20), w2y(0), w2x(22.6), H], fill=(3, 4, 8, 255))
d.rectangle([w2x(20), w2y(0), w2x(22.6), H], outline=(36, 40, 60, 255), width=2)

# --- khedivial tower finale (visible when CAM ~99) ---
box(92.0, 106.0, 8.45, -2, (26, 29, 48, 255), (58, 66, 96, 255))
paste_quad(facade, 95.5, 5.425, 7.0, 6.05, (0, 0), 0.0)
paste_quad(facade, 102.5, 5.425, 7.0, 6.05, (0, 0), 0.0, flip=True)
for l in [[92.9,94.5,1.2],[96.0,97.6,2.5],[99.1,100.7,3.8],[102.2,103.8,5.15],[104.0,105.6,6.5],[101.8,103.0,7.55]]:
    d.rectangle([w2x(l[0]), w2y(l[2]) - int(.32*S), w2x(l[1]), w2y(l[2])], fill=(46, 50, 74, 255))
d.rectangle([w2x(94.0), w2y(11.4), w2x(95.0), w2y(8.4)], fill=(20, 22, 36, 255))
# endzone glow on the roof
ex, ey = w2x(103.8), w2y(9.4)
d.ellipse([ex-70, ey-70, ex+70, ey+70], fill=(255, 226, 150, 130))
d.rectangle([ex-40, ey-55, ex+40, ey+55], fill=(255, 240, 200, 220))
# funduq sign
funduq = Image.open(f"{T}/sign_funduq.png").convert("RGBA")
paste_quad(funduq, 115.0, 2.85, 5.8, 1.21, (0, 0), 0.0)
# checkpoint flag
d.line([w2x(91.6), w2y(0), w2x(91.6), w2y(3)], fill=(40, 44, 66, 255), width=5)
d.polygon([(w2x(91.6), w2y(3)), (w2x(92.3), w2y(2.85)), (w2x(91.6), w2y(2.7))], fill=(255, 196, 116, 255))

# figures (placeholders for the mock)
def capsule(x, y, w, h, col):
    d.rounded_rectangle([w2x(x) - w * S / 2, w2y(y) - h * S, w2x(x) + w * S / 2, w2y(y)],
                        radius=w * S / 2, fill=col)
def enemy(x, y, tint=(210, 60, 50, 255)):
    # lean-forward running pose capsule + tiny "!" above
    capsule(x, y, 0.7, 1.7, (196, 44, 38, 255))
    fnt_y = w2y(y) - int(2.3 * S)
    d.text((w2x(x), fnt_y), "!", fill=(255, 216, 60, 255), anchor="mm", font_size=42)
enemy(33.0, 2.4)           # shops-roof thug chasing
enemy(36.5, 0.0)           # street thug
capsule(30.6, 0.0, 0.7, 1.7, (240, 220, 200, 255))  # Tito dash pose

# cool+haze grade + mild vignette for the mood
img = ImageEnhance.Color(img).enhance(1.06)
vig = Image.new("L", (W, H), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-W * 0.25, -H * 0.35, W * 1.25, H * 1.3], fill=255)
img = Image.composite(img, Image.new("RGB", (W, H), (4, 5, 12)),
                      vig.filter(ImageFilter.GaussianBlur(160)))
out = sys.argv[3] if len(sys.argv) > 3 else f"{T}/../cairo_concept_mock.png"
img.save(out)
print("saved", out)
print("mock saved to assets/textures/cairo_concept_mock.png")
