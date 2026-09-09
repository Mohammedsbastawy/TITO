#!/usr/bin/env python3
## PBR texture kit for the prologue: weathered red-brick + peeling plaster,
## rain-slicked asphalt, corrugated shutter metal — each with albedo,
## a generated normal map, and a roughness map (AAA stack, procedural).
import numpy as np
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = "/home/user/TITO/assets/textures/prologue"
import os
os.makedirs(OUT, exist_ok=True)
rng = random.Random(777)


def normal_from_height(h: np.ndarray, strength=2.6) -> Image.Image:
    gy, gx = np.gradient(h.astype(np.float32) / 255.0)
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(gx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln * .5 + .5, ny / ln * .5 + .5, nz / ln * .5 + .5], -1)
    return Image.fromarray((n * 255).astype(np.uint8), "RGB")


def plaster_mask(size, blobs, blur=9):
    """torn plaster patches: random blobs blurred -> threshold"""
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    W, H = size
    for _ in range(blobs):
        cx, cy = rng.randint(0, W), rng.randint(0, H)
        r = rng.randint(50, 150)
        pts = [(cx + rng.randint(-r, r), cy + rng.randint(-r, r)) for _ in range(8)]
        d.polygon(pts, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.array(m) > 110


def gen_brick_wall():
    S = 1024
    bw, bh, mortar = 86, 32, 7
    base = np.zeros((S, S, 3), np.uint8)
    height = np.zeros((S, S), np.uint8)
    # brick courses with running-bond offset
    for row, y in enumerate(range(0, S, bh + mortar)):
        off = (bw // 2) if row % 2 else 0
        for x in range(-bw, S + bw, bw + mortar):
            tint = rng.randint(-14, 16)
            c = (118 + tint, 62 + tint // 3, 52 + tint // 4)          # cairo red brick
            x0, x1 = x + off, x + off + bw
            base[max(0, y):y + bh, max(0, x0):min(S, x1)] = c
            height[max(0, y):y + bh, max(0, x0):min(S, x1)] = 150
    # mortar
    base[height < 150] = (66, 60, 58)
    # grain + weather noise
    noise = rng.random()
    n = np.random.default_rng(7).normal(0, 11, (S, S, 1))
    base = np.clip(base.astype(np.int16) + n, 0, 255).astype(np.uint8)
    # peeling plaster patches (raised, pale)
    mask = plaster_mask((S, S), 13)
    plaster_col = np.array([196, 184, 160], np.uint8)
    base[mask] = (base[mask] * 0.25 + plaster_col * 0.75).astype(np.uint8)
    height[mask] = 205
    # plaster cracks (dark thin lines inside plaster)
    crack = np.random.default_rng(3).normal(0, 9, (S, S))
    base[mask] = np.clip(base[mask].astype(np.int16) + crack[mask, None], 0, 255).astype(np.uint8)
    # grime: dark streaks from the top, damp band at the bottom
    streak = np.linspace(0.55, 1.0, S)[:, None].repeat(S, 1)
    damp = np.clip((np.arange(S) - S * 0.72) / (S * 0.28), 0, 1)[:, None].repeat(S, 1)
    albedo = (base * streak[..., None] * (1 - 0.35 * damp[..., None])).astype(np.uint8)
    # roughness: brick ~0.75, plaster ~0.9, damp band ~0.35 (wet sheen)
    rough = np.full((S, S), 190, np.uint8)
    rough[mask] = 228
    rough = np.clip(rough - (damp * 150).astype(np.uint8), 40, 255).astype(np.uint8)
    Image.fromarray(albedo).save(f"{OUT}/wall_brick.png", optimize=True)
    normal_from_height(height, 3.2).save(f"{OUT}/wall_brick_n.png", optimize=True)
    Image.fromarray(rough).save(f"{OUT}/wall_brick_r.png", optimize=True)


def gen_asphalt():
    S = 1024
    n = np.random.default_rng(11).normal(0, 10, (S, S))
    albedo = np.clip(30 + n, 0, 255).astype(np.uint8)
    albedo = np.stack([albedo, albedo + 2, albedo + 8], -1).astype(np.uint8)
    height = np.full((S, S), 128, np.uint8)
    # cracks
    d = ImageDraw.Draw(Image.fromarray(height))
    for _ in range(10):
        x, y = rng.randint(0, S), rng.randint(0, S)
        for seg in range(rng.randint(3, 7)):
            nx, ny = x + rng.randint(-90, 90), y + rng.randint(-90, 90)
            d.line([x, y, nx, ny], fill=40, width=3)
            x, y = nx, ny
    height = np.array(d._image)
    # oil / fuel stains: darker blobs, VERY low roughness (mirror-ish when wet)
    rough = np.full((S, S), 205, np.uint8)
    stain = Image.new("L", (S, S), 0)
    ds = ImageDraw.Draw(stain)
    for _ in range(8):
        cx, cy, r = rng.randint(0, S), rng.randint(0, S), rng.randint(40, 130)
        ds.ellipse([cx - r, cy - r * 2 // 3, cx + r, cy + r * 2 // 3], fill=255)
    stain = stain.filter(ImageFilter.GaussianBlur(22))
    st = np.array(stain)
    albedo[st > 90] = (18, 16, 24)
    rough[st > 90] = 60
    # worn center-line dashes
    for x0 in range(0, S, 128):
        albedo[492:502, x0:x0 + 64] = (120, 118, 96)
        rough[492:502, x0:x0 + 64] = 180
    Image.fromarray(albedo).save(f"{OUT}/asphalt_wet.png", optimize=True)
    normal_from_height(height, 2.0).save(f"{OUT}/asphalt_wet_n.png", optimize=True)
    Image.fromarray(rough).save(f"{OUT}/asphalt_wet_r.png", optimize=True)


def gen_shutter():
    S = 512
    albedo = np.zeros((S, S, 3), np.uint8)
    height = np.zeros((S, S), np.uint8)
    for y in range(S):
        band = (y // 42) % 2
        v = 92 if band == 0 else 58
        albedo[y, :] = (v, v + 3, v + 9)
        height[y, :] = 235 if (y % 42) < 5 else (150 if band == 0 else 90)
    rust = np.random.default_rng(5).normal(0, 8, (S, S, 1))
    albedo = np.clip(albedo.astype(np.int16) + rust.astype(np.int16), 0, 255).astype(np.uint8)
    for _ in range(7):  # rust streaks running down
        x = rng.randint(10, S - 10)
        w = rng.randint(3, 9)
        albedo[:, x:x + w] = np.clip(albedo[:, x:x + w].astype(np.int16) * 0.8
                                     + np.array([80, 42, 20], np.int16) * 0.35, 0, 255).astype(np.uint8)
    rough = np.full((S, S), 170, np.uint8)
    Image.fromarray(albedo).save(f"{OUT}/shutter.png", optimize=True)
    normal_from_height(height, 3.8).save(f"{OUT}/shutter_n.png", optimize=True)
    Image.fromarray(rough).save(f"{OUT}/shutter_r.png", optimize=True)


def gen_roof_concrete():
    S = 1024
    n = np.random.default_rng(21).normal(0, 9, (S, S))
    albedo = np.clip(np.stack([52 + n, 54 + n, 62 + n], -1), 0, 255).astype(np.uint8)
    height = np.full((S, S), 128, np.uint8)
    d = ImageDraw.Draw(Image.fromarray(height))
    for gx in range(0, S, 256):  # expansion joints
        d.line([gx, 0, gx, S], fill=60, width=5)
        d.line([0, gx, S, gx], fill=60, width=5)
    height = np.array(d._image)
    rough = np.full((S, S), 150, np.uint8)   # rain-wet concrete
    Image.fromarray(albedo).save(f"{OUT}/roof_concrete.png", optimize=True)
    normal_from_height(height, 2.6).save(f"{OUT}/roof_concrete_n.png", optimize=True)
    Image.fromarray(rough).save(f"{OUT}/roof_concrete_r.png", optimize=True)


if __name__ == "__main__":
    gen_brick_wall()
    gen_asphalt()
    gen_shutter()
    gen_roof_concrete()
    print("prologue PBR kit done")
