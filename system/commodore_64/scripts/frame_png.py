#!/usr/bin/env python3
"""Write a simulator FRAME/RUNF JSON reply's raster as a PNG (no dependencies)."""
import json
import struct
import sys
import zlib

# Display palette only (Philip "Pepto" Timmermann's colodore values); the
# VIC-II's analog luma/chroma output is not modeled.
PALETTE = [0x000000, 0xffffff, 0x813338, 0x75cec8, 0x8e3c97, 0x56ac4d, 0x2e2c9b, 0xedf171,
           0x8e5029, 0x553800, 0xc46c71, 0x4a4a4a, 0x7b7b7b, 0xa9ff9f, 0x706deb, 0xb2b2b2]


def write_png(path, frame, rows, cols, crop):
    top, bottom, left, right = crop
    raw = bytearray()
    for y in range(top, bottom):
        raw.append(0)
        for x in range(left, right):
            c = PALETTE[int(frame[y * cols + x], 16)]
            raw += bytes(((c >> 16) & 255, (c >> 8) & 255, c & 255))
    width, height = right - left, bottom - top
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as out:
        out.write(png)


if __name__ == "__main__":
    state = json.loads(open(sys.argv[1]).read())
    crop = tuple(int(v) for v in sys.argv[3].split(",")) if len(sys.argv) > 3 else (0, state["rows"], 0, state["cols"])
    write_png(sys.argv[2], state["frame"], state["rows"], state["cols"], crop)
