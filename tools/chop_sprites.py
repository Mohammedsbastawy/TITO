#!/usr/bin/env python3
"""Cut AI-generated sprite sheets (solid chroma background) into named
transparent PNGs ready for Godot. Segmentation uses a HARD chroma mask
(speckle-proof); crops keep the SOFT feathered alpha for clean edges.
Backdrops (full-frame art) are copied through untouched."""
import os
import numpy as np
from PIL import Image, ImageDraw

RAW = '/home/user/TITO/assets2d/gen/env_raw'
OUT = '/home/user/TITO/assets2d/sprites/env'
GAP = 28          # px of fully-empty space that separates items
TOL = 95          # soft feather width for the visible alpha edge

SHEETS = {
    'vehicles': ['taxi', 'sedan_dark', 'sedan_rust', 'van'],
    'street_props': ['cafe_front', 'shutter', 'barrier', 'lamp_post',
                     'sandbags', 'crate_stand', 'market_table'],
    'rooftop_kit': ['girder', 'floodlight', 'water_tank', 'ac_unit',
                    'antenna', 'fence'],
}
BACKDROPS = ['night_sky', 'skyline_far', 'facades_mid', 'street_ground']


def chroma_key(im: Image.Image):
    rgba = np.asarray(im.convert('RGBA')).astype(np.int16)
    corners = np.concatenate([rgba[:12, :12].reshape(-1, 4),
                              rgba[:12, -12:].reshape(-1, 4),
                              rgba[-12:, :12].reshape(-1, 4),
                              rgba[-12:, -12:].reshape(-1, 4)])
    key = np.median(corners, axis=0)[:3]
    dist = np.sqrt(((rgba[:, :, :3] - key) ** 2).sum(axis=2))
    hard = dist > 120.0                 # segmentation mask
    a = np.clip((dist - (TOL - 30)) * (255 / 60), 0, 255)
    rgba[:, :, 3] = np.minimum(rgba[:, :, 3], a.astype(np.int16))
    soft = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), 'RGBA')
    return soft, hard


def runs(mask_1d: np.ndarray, gap: int) -> list:
    out, start, empty = [], None, 0
    for i, v in enumerate(mask_1d):
        if v:
            if empty >= gap and start is not None:
                out.append((start, i - empty))
                start = None
            empty = 0
            if start is None:
                start = i
        else:
            empty += 1
    if start is not None:
        out.append((start, len(mask_1d)))
    return [(a, b) for a, b in out if b - a > 12]


def _label_boxes(hard: np.ndarray) -> list:
    """Connected-component boxes (8-connectivity), speckles dropped."""
    from scipy import ndimage
    labels, count = ndimage.label(hard, structure=np.ones((3, 3)))
    boxes = []
    for lab in range(1, count + 1):
        ys, xs = np.where(labels == lab)
        if ys.size < 500:
            continue
        boxes.append((int(xs.min()), int(ys.min()),
                      int(xs.max()) + 1, int(ys.max()) + 1))
    return boxes


def chop(name: str, names: list[str]) -> list[str]:
    im, hard = chroma_key(Image.open(os.path.join(RAW, name + '.png')))
    boxes = _label_boxes(hard)
    print(f'  [{name}] raw boxes: {len(boxes)}')
    # reading order: cluster by row (top edges within 160 px), left->right
    boxes.sort(key=lambda b: b[1])
    rows_: list[list[tuple]] = []
    for b in boxes:
        for row in rows_:
            if abs(b[1] - row[0][1]) < 160:
                row.append(b)
                break
        else:
            rows_.append([b])
    ordered = []
    for row in rows_:
        ordered.extend(sorted(row, key=lambda b: b[0]))
    saved = []
    for i, (x0, y0, x1, y1) in enumerate(ordered):
        if i >= len(names):
            break
        pad = 5
        crop = im.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad))
        path = os.path.join(OUT, names[i] + '.png')
        crop.save(path)
        saved.append(f'{names[i]} {crop.size}')
    return saved


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for sheet, names in SHEETS.items():
        print(sheet, '->', ', '.join(chop(sheet, names)))
    for b in BACKDROPS:
        Image.open(os.path.join(RAW, b + '.png')).save(
            os.path.join(OUT, b + '.png'))
        print(b, '-> copied')
    thumbs = sorted(f for f in os.listdir(OUT)
                    if f.endswith('.png') and not f.startswith('_'))
    cell = 300
    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    board = Image.new('RGB', (cols * cell, rows * (cell + 24)), (14, 16, 28))
    d = ImageDraw.Draw(board)
    for i, f in enumerate(thumbs):
        t = Image.open(os.path.join(OUT, f)).convert('RGBA')
        t.thumbnail((cell - 20, cell - 20))
        x, y = (i % cols) * cell, (i // cols) * (cell + 24)
        board.paste(t, (x + (cell - t.size[0]) // 2,
                        y + (cell - t.size[1]) // 2), t)
        d.text((x + 8, y + cell + 4), f, fill=(200, 205, 230))
    board.save(os.path.join(OUT, '_library_contact.png'))
    print('contact sheet ok')


if __name__ == '__main__':
    main()
