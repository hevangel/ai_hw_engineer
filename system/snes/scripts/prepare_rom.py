#!/usr/bin/env python3
"""Turn a SNES cartridge image (.sfc/.smc) into the work/ files the board
loads: a $readmemh ROM image and the plusargs for its memory map.
Prints the plusargs on stdout. ROM images are never committed."""
import argparse
from pathlib import Path


def header_score(rom, base, hirom):
    if len(rom) < base + 0x40:
        return -1
    h = rom[base:base + 0x40]
    score = 0
    checksum = h[0x1E] | h[0x1F] << 8
    complement = h[0x1C] | h[0x1D] << 8
    if checksum ^ complement == 0xFFFF:
        score += 4
    mode = h[0x15] & 0xEF
    if mode == (0x21 if hirom else 0x20):
        score += 2
    reset = h[0x3C] | h[0x3D] << 8
    if reset >= 0x8000:
        score += 1
    if all(32 <= c < 127 for c in h[:21]):
        score += 1
    return score


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rom")
    parser.add_argument("out", help="output .hex path")
    args = parser.parse_args()
    data = Path(args.rom).read_bytes()
    if len(data) % 1024 == 512:
        data = data[512:]  # copier header
    lo = header_score(data, 0x7FC0, False)
    hi = header_score(data, 0xFFC0, True)
    hirom = hi > lo
    base = 0xFFC0 if hirom else 0x7FC0
    size = 1
    while size < len(data):
        size <<= 1
    image = bytearray(size)
    image[:len(data)] = data
    # Non power-of-two images mirror their upper part (common 1.5/3 MB carts).
    if size != len(data):
        top = 1
        while top * 2 <= len(data):
            top *= 2
        for i in range(len(data), size):
            image[i] = data[top + (i - top) % (len(data) - top)]
    sram_kb = (1 << data[base + 0x18]) if 0 < data[base + 0x18] <= 7 else 0
    Path(args.out).write_text("".join(f"{b:02x}\n" for b in image))
    sram_mask = max(sram_kb * 1024 - 1, 0)
    print(f"+rom={args.out} +hirom={int(hirom)} +rommask={size - 1} "
          f"+srammask={sram_mask} +sramen={int(sram_kb > 0)}")


if __name__ == "__main__":
    main()
