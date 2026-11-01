#!/usr/bin/env python3
"""Rebuilds the iOS AppIcon set from assets/icon/app_icon_original.png.

The source art is a rounded icon on a near-white background. iOS applies its
own rounded mask, and the App Store icon must be a full-bleed square without
transparency, so the white background is replaced by the icon's own edge
colours (extended outwards) before resizing. The original is never modified.

Usage (from the repo root):  python3 assets/icon/make_ios_icons.py
Needs: Pillow, numpy.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/icon/app_icon_original.png"
SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
MASTER = ROOT / "assets/icon/app_icon_1024_fullbleed.png"


def full_bleed(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    h, w, _ = a.shape
    # Background = near-white pixels connected to the image border.
    near_white = a.min(axis=2) > 232
    bg = np.zeros((h, w), bool)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + \
            [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or bg[y, x] or not near_white[y, x]:
            continue
        bg[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    # Cover the anti-aliased rim too (grow the mask by 6 px).
    for _ in range(6):
        g = bg.copy()
        g[1:, :] |= bg[:-1, :]; g[:-1, :] |= bg[1:, :]
        g[:, 1:] |= bg[:, :-1]; g[:, :-1] |= bg[:, 1:]
        bg = g
    # Fill each background pixel with the first real pixel found walking
    # towards the centre (the blue rim extends outwards).
    out = a.copy()
    ys, xs = np.nonzero(bg)
    cy, cx = (h - 1) / 2, (w - 1) / 2
    dy, dx = cy - ys, cx - xs
    norm = np.maximum(np.hypot(dy, dx), 1)
    dy, dx = dy / norm, dx / norm
    todo = np.ones(len(ys), bool)
    for k in range(1, 400):
        sy = np.clip(np.round(ys + dy * k).astype(int), 0, h - 1)
        sx = np.clip(np.round(xs + dx * k).astype(int), 0, w - 1)
        ok = todo & ~bg[sy, sx]
        out[ys[ok], xs[ok]] = a[sy[ok], sx[ok]]
        todo &= ~ok
        if not todo.any():
            break
    return Image.fromarray(out.astype(np.uint8), "RGB")


def main() -> None:
    master = full_bleed(Image.open(SRC)).resize((1024, 1024), Image.LANCZOS)
    master.save(MASTER, optimize=True)
    contents = json.loads((SET / "Contents.json").read_text())
    for entry in contents["images"]:
        size = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(size * scale)
        # RGB, no alpha (the App Store rejects icons with transparency).
        master.resize((px, px), Image.LANCZOS).save(SET / entry["filename"], optimize=True)
        print(f'{entry["idiom"]:>13} {entry["size"]:>9} @{scale}x -> {px}px {entry["filename"]}')


if __name__ == "__main__":
    main()
