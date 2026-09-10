#!/usr/bin/env python3
"""Slice the artist's hero animation sheets (2752x1536 transparent PNGs).

Auto-detects frame clusters per row band, tight-crops each frame, then
re-normalizes every animation so the character is world-scale consistent
across all sheets (the artist exports run/sprint ~55% smaller than idle).

Per animation:
  - baseline  = max frame bottom (the sheet's ground line)
  - lift_i    = (baseline - bottom_i) * k   baked into the cell (air frames)
  - k (scale) = H_REF / max_i(height_i + lift_i)
  - cell      = transparent (frame_w*k + 2*PAD) x (height_i*k + lift_i + 2*PAD)
    frame anchored so its source bottom maps to cell bottom minus lift.
Cells are saved as f_00.png .. f_XX.png into assets2d/sprites/chars/anim/<name>/.

H_REF = median tight height of tito_idle (the standing reference).

Usage: python3 tools/slice_hero_sheets.py [--qa]
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets2d" / "gen" / "chars_raw"
OUT = ROOT / "assets2d" / "sprites" / "chars" / "anim"

SHEETS = ["tito_idle", "tito_run", "tito_sprint", "tito_jump", "tito_fall", "tito_land"]
ALPHA_T = 24
PAD = 4


def runs_1d(mask: np.ndarray) -> list[tuple[int, int]]:
    runs, s = [], None
    for i, v in enumerate(mask):
        if v and s is None:
            s = i
        elif not v and s is not None:
            runs.append((s, i))
            s = None
    if s is not None:
        runs.append((s, len(mask)))
    return runs


def frame_bboxes(alpha: np.ndarray) -> list[tuple[int, int, int, int]]:
    """Tight bboxes (x0, y0, x1, y1) in reading order across row bands."""
    ink = alpha >= ALPHA_T
    boxes: list[tuple[int, int, int, int]] = []
    for r0, r1 in runs_1d(ink.max(axis=1)):
        band = ink[r0:r1]
        for c0, c1 in runs_1d(band.max(axis=0)):
            sub = ink[r0:r1, c0:c1]
            ys = np.where(sub.max(axis=1))[0]
            boxes.append((c0, r0 + int(ys.min()), c1, r0 + int(ys.max()) + 1))
    return boxes


def slice_sheet(name: str, h_ref: float, qa: bool) -> dict:
    src = Image.open(RAW / f"{name}.png").convert("RGBA")
    alpha = np.array(src)[:, :, 3]
    if int(alpha[0, 0]) > 16:
        raise SystemExit(f"{name}: corner alpha != 0 — expected transparent sheet")
    boxes = frame_bboxes(alpha)
    if not boxes:
        raise SystemExit(f"{name}: no ink found")

    heights = [b[3] - b[1] for b in boxes]
    widths = [b[2] - b[0] for b in boxes]
    baseline = max(b[3] for b in boxes)
    headroom = max((b[3] - b[1]) + (baseline - b[3]) for b in boxes)
    k = h_ref / float(headroom)

    out_dir = OUT / name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    cells = []
    for i, (x0, y0, x1, y1) in enumerate(boxes):
        fw, fh = x1 - x0, y1 - y0
        cw = round(fw * k) + PAD * 2
        ch = round(fh * k) + round((baseline - y1) * k) + PAD * 2
        crop = src.crop((x0, y0, x1, y1)).resize((round(fw * k), round(fh * k)), Image.LANCZOS)
        cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cell.alpha_composite(crop, (PAD, PAD + round((baseline - y1) * k)))
        cell.save(out_dir / f"f_{i:02d}.png")
        cells.append(cell)

    print(f"{name}: frames={len(boxes)} k={k:.3f} "
          f"tight=({min(widths)}..{max(widths)}x{min(heights)}..{max(heights)}) "
          f"cell~{cells[0].size} -> {out_dir.relative_to(ROOT)}")

    if qa:
        tile = 16
        board_w = sum(c.width + 20 for c in cells) + 20
        board_h = max(c.height for c in cells) + 40
        board = Image.new("RGBA", (board_w, board_h), (128, 128, 128, 255))
        for ty in range(0, board_h, tile):
            for tx in range(0, board_w, tile):
                if (tx // tile + ty // tile) % 2 == 0:
                    chk = Image.new("RGBA", (tile, tile), (90, 90, 90, 255))
                    board.paste(chk, (tx, ty))
        x = 20
        for c in cells:
            board.alpha_composite(c, (x, 20))
            x += c.width + 20
        qa_path = Path("/tmp") / f"qa_{name}.png"
        board.convert("RGB").resize((min(1300, board_w), int(board_h * min(1.0, 1300 / board_w))), Image.LANCZOS).save(qa_path)
        print("  qa:", qa_path)

    return {"frames": len(boxes), "k": k, "cell_h": cells[0].height}


def main() -> None:
    qa = "--qa" in sys.argv
    ref_boxes = frame_bboxes(np.array(Image.open(RAW / "tito_idle.png").convert("RGBA"))[:, :, 3])
    h_ref = float(np.median([b[3] - b[1] for b in ref_boxes]))
    print(f"H_REF (idle median tight height) = {h_ref:.0f}px")
    for name in SHEETS:
        slice_sheet(name, h_ref, qa)


if __name__ == "__main__":
    main()
