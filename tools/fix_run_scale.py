#!/usr/bin/env python3
"""FIX: Tito shrinks when running.

The run/sprint sheets were drawn smaller than idle inside the shared 1319px
canvases (measured ink: idle ~1265px vs run ~921px vs sprint ~800px), so at a
uniform per-frame scale Tito lost ~27-37% of his on-screen height the moment
he started moving. This tool re-normalises ink height per animation while
keeping the shared bottom ground-line, so every animation reads at the same
body height as idle. Pure asset fix; engine code is unchanged.
"""
from PIL import Image
import numpy as np
import glob

TARGETS = {"tito_run": 1210, "tito_sprint": 1150}  # ink height vs idle ~1265
GROUND_ROW = 1316  # feet baseline inside the 1319-tall canvas
ANIM_DIR = "assets2d/sprites/chars/anim"


def ink_bbox(img):
    alpha = np.array(img.getchannel("A"))
    m = alpha > 40
    ys = np.where(m.any(axis=1))[0]
    xs = np.where(m.any(axis=0))[0]
    return ys.min(), ys.max(), xs.min(), xs.max()


def main():
    for anim, target_h in TARGETS.items():
        d = f"{ANIM_DIR}/{anim}"
        files = sorted(glob.glob(d + "/f_*.png"))
        if not files:
            print(anim, "no frames, skipped")
            continue
        boxes = [ink_bbox(Image.open(f).convert("RGBA")) for f in files]
        max_ink = max(y1 - y0 for y0, y1, _, _ in boxes)
        scale = target_h / float(max_ink)
        for f, (y0, y1, x0, x1) in zip(files, boxes):
            im = Image.open(f).convert("RGBA")
            ink = im.crop((x0, y0, x1, y1))
            nw = max(int(round(ink.width * scale)), 1)
            nh = max(int(round(ink.height * scale)), 1)
            ink = ink.resize((nw, nh), Image.LANCZOS)
            canvas = Image.new("RGBA", (nw, 1319), (0, 0, 0, 0))
            canvas.paste(ink, (0, GROUND_ROW - nh), ink)
            canvas.save(f)
        print(f"{anim}: {len(files)} frames, ink {max_ink}px -> {target_h}px "
              f"(x{scale:.3f}), feet re-anchored at row {GROUND_ROW}")


if __name__ == "__main__":
    main()
