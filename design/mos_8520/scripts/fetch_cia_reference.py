#!/usr/bin/env python3
"""Fetch and verify MAME's unchanged mos6526.cpp/.h (BSD-3-Clause), the 8520 oracle.

Originals stay under ignored work/reference; a cached file with an
unexpected digest is rejected, never overwritten.
"""
from pathlib import Path
import hashlib
import urllib.request

REVISION = "41a494b6ef80adc924ccb2bdba1ee69580276e0c"
BASE = f"https://raw.githubusercontent.com/mamedev/mame/{REVISION}/src/devices/machine/"
ROOT = Path(__file__).resolve().parents[1] / "work/reference"
FILES = {
    "mos6526.cpp": "7fded393c9fbcdcf3224085d7fce20fc6acc292dc795b00fb5fb312b8f27602f",
    "mos6526.h": "d2cde5ea197596fe17afe82c27f29e1994091479403a4a4db7d7702fca21f83c",
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
            raise SystemExit(f"MAME CIA reference hash mismatch: {name}")
        if not path.exists():
            path.write_bytes(data)
    print(f"Verified unchanged MAME {REVISION} mos6526.cpp/.h")


if __name__ == "__main__":
    main()
