#!/usr/bin/env python3
"""Cut AI-generated sprite sheets (solid chroma background) into named
transparent PNGs ready for Godot. Segmentation uses a HARD chroma mask
(speckle-proof); crops keep the SOFT feathered alpha for clean edges.

Modes per sheet:
  slice -> connected-component items, named left-to-right / row-major.
  whole -> key the background, crop the alpha bbox, save as one strip.
Backdrops (full-frame art) are copied through untouched.
Sheets may declare `erase_ground_line` to delete the inked baseline that
otherwise connects all characters into one blob."""
import os
import numpy as np
from PIL import Image, ImageDraw

RAW = '/home/user/TITO/assets2d/gen/env_raw'
OUT_ENV = '/home/user/TITO/assets2d/sprites/env'
OUT_CHARS = '/home/user/TITO/assets2d/sprites/chars'
GAP = 28          # px of fully-empty space that separates items
TOL = 95          # soft feather width for the visible alpha edge

SHEETS = {
    'vehicles': {'names': ['taxi', 'sedan_dark', 'sedan_rust', 'van']},
    'street_props': {'names': ['cafe_front', 'shutter', 'barrier', 'lamp_post',
                               'sandbags', 'crate_stand', 'market_table']},
    'rooftop_kit': {'names': ['girder', 'floodlight', 'water_tank', 'ac_unit',
                              'antenna', 'fence']},
    'clouds': {'names': ['cloud_1', 'cloud_2', 'cloud_3']},
    'scaffold_kit': {'names': ['scaffold_frame', 'brace', 'plank',
                               'ladder', 'plank_stack', 'ibeam_col']},
    'storefront_kit': {'names': ['awning_blue', 'awning_green', 'awning_beige',
                                 'neon_round', 'neon_stack', 'shutter_wide',
                                 'wire_banner']},
    'city_props2': {'names': ['toktok', 'news_kiosk', 'hose_reel',
                              'dish_cluster', 'pigeon_coop']},
    'mansion_garden_kit': {'names': ['hedge_arch', 'wall_stone', 'trash_bin',
                                     'fountain_dry', 'trellis', 'searchlight_pole',
                                     'grass_strip', 'van_armored']},
    'mansion_interior_kit': {'names': ['doors_mahogany', 'stairs_marble',
                                       'chandelier', 'column_tall', 'sconce',
                                       'rug_strip', 'locker_metal']},
    'mansion_sunroom_kit': {'names': ['french_window', 'table_flipped',
                                      'balustrade', 'plant_pot', 'armchair',
                                      'sideboard', 'iron_railing']},
    'mansion_facade_kit': {'names': ['facade_strip', 'entrance_arch', 'balcony',
                                     'window_shutter', 'cornice',
                                     'carriage_lamp', 'roofline', 'iron_gate',
                                     'floor_planks']},
    'curtain_sheet': {'names': ['curtain_panel']},
    'tree_line_sheet': {'mode': 'whole'},
    'paintings_sheet': {'names': ['painting_portrait', 'painting_landscape',
                                  'painting_stilllife']},
    'facades_b': {'mode': 'whole'},
    'facades_c': {'mode': 'whole'},
    'facades_d': {'mode': 'whole'},
    'chars': {'names': ['tito_idle', 'enforcer_idle', 'raven_idle'],
              'out': OUT_CHARS, 'erase_ground_line': False},
}
BACKDROPS = ['night_sky', 'skyline_far', 'facades_mid', 'street_ground']


def chroma_key(im: Image.Image):
    """Fixed magenta reference (255,0,255): corner-sampling breaks when a
    sprite touches all four corners (facade strips with rooftop clutter)."""
    rgba = np.asarray(im.convert('RGBA')).astype(np.int16)
    key = np.array([255, 0, 255])
    dist = np.sqrt(((rgba[:, :, :3] - key) ** 2).sum(axis=2))
    hard = dist > 120.0                 # segmentation mask
    a = np.clip((dist - 50) * (255 / 70), 0, 255)
    rgba[:, :, 3] = np.minimum(rgba[:, :, 3], a.astype(np.int16))
    # magenta despill: pull r/b down toward g wherever purple dominates,
    # everywhere (fully-opaque blend pixels carry the visible halo)
    r, g, b = rgba[:, :, 0], rgba[:, :, 1], rgba[:, :, 2]
    excess = np.clip(np.minimum(r, b) - g, 0, None)
    purple = excess > 25
    rgba[:, :, 0] = np.where(purple, r - excess, r)
    rgba[:, :, 2] = np.where(purple, b - excess, b)
    soft = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), 'RGBA')
    return soft, hard


def _erase_baseline(soft: Image.Image, hard: np.ndarray):
    """Remove the full-width ink ground line (if any) so characters split."""
    h, w = hard.shape
    dark = hard[:, :].sum(axis=1) / float(w)          # ink fraction per row
    zone = dark[int(h * 0.55):]                        # feet live in lower half
    r = int(np.argmax(zone)) + int(h * 0.55)
    if zone.max() < 0.4:                               # no line found, skip
        return soft, hard
    a = np.asarray(soft).copy()
    for y in range(max(0, r - 1), min(h, r + 2)):
        a[y, :, 3] = 0
        hard[y, :] = False
    print(f'  erased ground line at row {r}')
    return Image.fromarray(a), hard


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


def _alpha_bbox(im: Image.Image) -> tuple:
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 8)
    if ys.size == 0:
        return 0, 0, im.size[0], im.size[1]
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def chop(name: str, spec: dict) -> list[str]:
    out_dir = spec.get('out', OUT_ENV)
    os.makedirs(out_dir, exist_ok=True)
    im, hard = chroma_key(Image.open(os.path.join(RAW, name + '.png')))
    if spec.get('erase_ground_line'):
        im, hard = _erase_baseline(im, hard)
    if spec.get('mode') == 'whole':
        pad = 4
        x0, y0, x1, y1 = _alpha_bbox(im)
        crop = im.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad))
        path = os.path.join(out_dir, name + '.png')
        crop.save(path)
        return [f'{name} {crop.size}']
    names = spec['names']
    boxes = _label_boxes(hard)
    print(f'  [{name}] raw boxes: {len(boxes)}')
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
        path = os.path.join(out_dir, names[i] + '.png')
        crop.save(path)
        saved.append(f'{names[i]} {crop.size}')
    return saved


def main() -> None:
    os.makedirs(OUT_ENV, exist_ok=True)
    for sheet, spec in SHEETS.items():
        print(sheet, '->', ', '.join(chop(sheet, spec)))
    for b in BACKDROPS:
        Image.open(os.path.join(RAW, b + '.png')).save(
            os.path.join(OUT_ENV, b + '.png'))
        print(b, '-> copied')
    thumbs = []
    for d in (OUT_ENV, OUT_CHARS):
        thumbs += [os.path.join(d, f) for f in sorted(os.listdir(d))
                   if f.endswith('.png') and not f.startswith('_')]
    cell = 300
    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    board = Image.new('RGB', (cols * cell, rows * (cell + 24)), (14, 16, 28))
    d = ImageDraw.Draw(board)
    for i, f in enumerate(thumbs):
        t = Image.open(f).convert('RGBA')
        t.thumbnail((cell - 20, cell - 20))
        x, y = (i % cols) * cell, (i // cols) * (cell + 24)
        board.paste(t, (x + (cell - t.size[0]) // 2,
                        y + (cell - t.size[1]) // 2), t)
        d.text((x + 8, y + cell + 4), os.path.basename(f), fill=(200, 205, 230))
    board.save(os.path.join(OUT_ENV, '_library_contact.png'))
    print('contact sheet ok')


if __name__ == '__main__':
    main()
