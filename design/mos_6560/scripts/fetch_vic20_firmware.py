#!/usr/bin/env python3
"""Fetch and verify original Commodore VIC-20 firmware for boot regression.

The images are downloaded into ignored work/vic20 and never committed;
firmware copyright remains with its owners. SHA-256 digests are pinned
here; their SHA-1 values equal the ROM_LOAD entries of MAME's vic20 driver
at the pinned MAME revision (see report/vic20_software.md). An existing
file with an unexpected digest is rejected, never overwritten.
"""
from pathlib import Path
import hashlib
import urllib.request

BASE = "https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/vic20/"
ROOT = Path(__file__).resolve().parents[1] / "work/vic20"
FILES = {
    "basic.901486-01.bin":
        "8be2d882e0eeb1c6923a43660236ea69d43ca8a3bd0613b1b6c910601584fbed",
    "kernal.901486-06.bin":
        "8fc94bd895f488ac0ae1a52abdc32988cd63c777770b89a9d415513098535cc2",
    "kernal.901486-07.bin":
        "ff6d1416b91a71f5240a5bb8adc9fdc1b955374c48322ca47b3e436334f168fb",
    "characters.901460-03.bin":
        "bda280726cfe069ca70ef5e2f2d95a29f69d3950c859a12e6979464963fcf502",
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, expected in FILES.items():
        path = ROOT / name
        if path.exists():
            data = path.read_bytes()
        else:
            with urllib.request.urlopen(BASE + name, timeout=60) as response:
                data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit(f"Original VIC-20 firmware hash mismatch: {name}")
        if not path.exists():
            path.write_bytes(data)
    print("Verified original VIC-20 901486-01 BASIC, 901486-06/-07 KERNAL and "
          "901460-03 character ROMs; firmware copyright remains with its owners")


if __name__ == "__main__":
    main()
