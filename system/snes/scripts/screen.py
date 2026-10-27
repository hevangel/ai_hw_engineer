#!/usr/bin/env python3
"""Helpers shared by the SNES test scripts: decode the simulator's SCREEN
reply (512 x 240 BGR555) and compare it with a 256-wide reference image."""
import base64
import struct


def rgb555(v):
    r, g, b = v & 31, (v >> 5) & 31, (v >> 10) & 31
    return (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2)


def decode(reply):
    raw = base64.b64decode(reply["screen"])
    w, h = reply["width"], reply["height"]
    words = struct.unpack(f"<{w * h}H", raw)
    return w, h, [rgb555(v) for v in words]


def to_image(reply, rows=224):
    from PIL import Image
    w, h, px = decode(reply)
    img = Image.new("RGB", (w, rows))
    img.putdata(px[:w * rows])
    return img


def compare(reply, reference_path, tolerance=10):
    """Fraction of reference pixels that differ (per-channel tolerance).
    A 256-wide reference is compared with the even columns of the frame."""
    from PIL import Image
    ref = Image.open(reference_path).convert("RGB")
    rw, rh = ref.size
    w, h, px = decode(reply)
    step = max(w // rw, 1)
    refpx = ref.load()
    rows = min(rh, h)
    bad = 0
    for y in range(rows):
        for x in range(rw):
            a = px[y * w + x * step]
            b = refpx[x, y]
            if any(abs(a[i] - b[i]) > tolerance for i in range(3)):
                bad += 1
    return bad / (rw * rows)
