#!/usr/bin/env python3
"""Helpers shared by the SNES test scripts: decode the simulator's SCREEN
reply (512 x 480 BGR555, progressive lines doubled) and compare it with a
reference image of 256 or 512 columns and 224/239 or 448/478 rows."""
import base64

import numpy as np


def decode(reply):
    """Frame as an (h, w, 3) uint8 RGB array."""
    w, h = reply["width"], reply["height"]
    v = np.frombuffer(base64.b64decode(reply["screen"]), dtype="<u2").reshape(h, w)
    rgb = np.stack([v & 31, (v >> 5) & 31, (v >> 10) & 31], axis=-1).astype(np.uint8)
    return (rgb << 3) | (rgb >> 2)


def to_image(reply, rows=448):
    from PIL import Image
    return Image.fromarray(decode(reply)[:rows])


def load_reference(path):
    from PIL import Image
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def compare(reply, ref, tolerance=10):
    """Fraction of reference pixels that differ by more than `tolerance` in
    any channel. A 256-wide reference is compared with the even columns and
    a 224-row reference with the even rows of the frame. A 225/240-row
    (450/480-row) reference also holds display line 0, which is never shown;
    frame row 0 is display line 1."""
    if not isinstance(ref, np.ndarray):
        ref = load_reference(ref)
    frame = decode(reply).astype(np.int16)
    rh, rw = ref.shape[:2]
    tall = rh >= 400
    sy, sx = (1 if tall else 2), frame.shape[1] // rw
    top = (2 if tall else 1) if rh in (225, 240, 450, 480) else 0
    ref = ref[top:]
    view = frame[::sy, ::sx][:ref.shape[0]]
    ref = ref[:view.shape[0]]
    bad = (np.abs(view - ref) > tolerance).any(axis=-1)
    return float(bad.mean())
