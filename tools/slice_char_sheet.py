#!/usr/bin/env python3
"""Slice hand-made character animation sheets into engine-ready frames.

Input : one PNG sheet per animation, uniform grid (frames x 1), dark bg.
Stage : corner-sampled bg keying -> per-frame alpha trim -> bottom-align feet,
        h-center into canonical cell -> save f_00..f_NN + QA contact strip.

Usage:  python3 tools/slice_char_sheet.py <sheet.png> <frame_count> <anim_name>
E.g.:   python3 tools/slice_char_sheet.py assets2d/gen/chars_raw/tito_run.png 8 tito_run
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

RAW = 'assets2d/gen/chars_raw'
OUT = 'assets2d/sprites/chars/anim'
KEY_BLEND_LO = 10     # dist below this -> fully bg
KEY_BLEND_RANGE = 22  # extra dist to reach fully-sprite


def slice_sheet(src: str, frames: int, name: str) -> list[str]:
    im = Image.open(src).convert('RGBA')
    a = np.asarray(im).astype(np.int16)
    hi, wi = a.shape[:2]
    corners = np.concatenate([a[:8, :8].reshape(-1, 4), a[:8, -8:].reshape(-1, 4),
                              a[-8:, :8].reshape(-1, 4), a[-8:, -8:].reshape(-1, 4)])
    key = np.median(corners, axis=0)[:3]
    dist = np.sqrt(((a[:, :, :3] - key) ** 2).sum(axis=2))
    alpha = np.clip((dist - KEY_BLEND_LO) * (255.0 / KEY_BLEND_RANGE), 0, 255)
    a[:, :, 3] = np.minimum(a[:, :, 3], alpha.astype(np.int16))
    keyed = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

    cw = wi / frames
    crops, maxw, maxh = [], 0, 0
    for i in range(frames):
        cell = keyed.crop((int(i * cw), 0, int((i + 1) * cw), hi))
        ca = np.asarray(cell)[:, :, 3]
        ys, xs = np.where(ca > 10)
        if ys.size == 0:
            print(f'  ! frame {i} empty — skipped')
            continue
        pad = 2
        x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
        x1, y1 = min(cell.width, xs.max() + 1 + pad), min(cell.height, ys.max() + 1 + pad)
        c = cell.crop((x0, y0, x1, y1))
        crops.append(c)
        maxw, maxh = max(maxw, c.width), max(maxh, c.height)

    dst = os.path.join(OUT, name)
    os.makedirs(dst, exist_ok=True)
    saved = []
    for i, c in enumerate(crops):
        cell = Image.new('RGBA', (maxw + 8, maxh + 6), (0, 0, 0, 0))
        cell.alpha_composite(c, ((maxw + 8 - c.width) // 2, maxh + 6 - c.height))
        p = os.path.join(dst, f'f_{i:02d}.png')
        cell.save(p)
        saved.append(p)
    print(f'  {name}: {len(crops)} frames, cell {maxw + 8}x{maxh + 6} -> {dst}')
    _contact(saved, os.path.join(OUT, f'_{name}_strip.png'))
    return saved


def _contact(paths: list[str], out: str) -> None:
    cell = 160
    board = Image.new('RGB', (len(paths) * cell, cell + 20), (16, 18, 30))
    d = ImageDraw.Draw(board)
    for i, p in enumerate(paths):
        t = Image.open(p).convert('RGBA')
        t.thumbnail((cell - 12, cell - 12))
        board.paste(t, (i * cell + (cell - t.width) // 2,
                        (cell - t.height) // 2), t)
        d.text((i * cell + 6, cell + 4), f'{i:02d}', fill=(190, 195, 225))
    board.save(out)


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    slice_sheet(sys.argv[1], int(sys.argv[2]), sys.argv[3])
