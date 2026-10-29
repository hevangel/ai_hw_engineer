#!/usr/bin/env python3
"""Fetch and verify unchanged, immutable PAL VIC reference headers.

The original zlib/libpng license notices are retained in the downloaded
files. Reference sources and generated products remain under ignored work/.
An existing file with an unexpected digest is rejected, never overwritten.
"""
from pathlib import Path
import hashlib
import urllib.request


COMMIT = "9e88298ce56319953ac7a43213a1120359f7a3a6"
BASE = f"https://raw.githubusercontent.com/floooh/chips/{COMMIT}/chips/"
ROOT = Path(__file__).resolve().parents[1] / "work/raster-reference"
FILES = {
    "m6561.h": "901526e4010d7d53bc4c1ccde27b54f6b0f80a384fe884f5ea0ab299a717b288",
    "chips_common.h": "f5992674dc6ddecd88a19b146d2259ba1142e4d2fce9b0620b14c7783965bb7b",
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
            raise SystemExit(f"Unchanged PAL VIC reference hash mismatch: {name}")
        if not path.exists():
            path.write_bytes(data)
    print(f"Verified unchanged floooh/chips PAL VIC reference at {COMMIT}")


if __name__ == "__main__":
    main()
