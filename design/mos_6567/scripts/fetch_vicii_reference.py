#!/usr/bin/env python3
"""Fetch and verify the unchanged MAME VIC-II implementation used as oracle.

MAME's mos6566.cpp/.h (BSD-3-Clause, Curt Coder) are compiled unchanged
against project-authored framework stubs in tb/mame_stubs. The floooh/chips
m6569.h (zlib) PAL model is pinned for the disagreement review only.
Originals stay under ignored work/; a cached file with an unexpected digest
is rejected, never overwritten.
"""
from pathlib import Path
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "work/reference"
MAME = "41a494b6ef80adc924ccb2bdba1ee69580276e0c"
CHIPS = "9e88298ce56319953ac7a43213a1120359f7a3a6"
FILES = {
    "mos6566.cpp": (f"https://raw.githubusercontent.com/mamedev/mame/{MAME}/src/devices/video/mos6566.cpp",
                    "5f09fcd058a07e53526cd8068e6a17778addd8b4bfbe4c45d528cc23da267a29"),
    "mos6566.h": (f"https://raw.githubusercontent.com/mamedev/mame/{MAME}/src/devices/video/mos6566.h",
                  "eaf828e424dc714ad4366235844e6912526f743f33fceee48817e712da85c454"),
    "m6569.h": (f"https://raw.githubusercontent.com/floooh/chips/{CHIPS}/chips/m6569.h",
                "8ba7e2296e34eb486b8cd9f3488814ab1af22c418b2e06a7716e01cbed820d29"),
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, (url, expected) in FILES.items():
        path = ROOT / name
        if path.exists():
            data = path.read_bytes()
        else:
            with urllib.request.urlopen(url, timeout=60) as response:
                data = response.read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit(f"VIC-II reference hash mismatch: {name}")
        if not path.exists():
            path.write_bytes(data)
    print(f"Verified unchanged MAME {MAME} mos6566.cpp/.h and floooh/chips {CHIPS} m6569.h")


if __name__ == "__main__":
    main()
