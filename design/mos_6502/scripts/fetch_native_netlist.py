#!/usr/bin/env python3
"""Fetch an unchanged, hash-pinned independent die-derived test oracle."""
from pathlib import Path
import hashlib
import urllib.request

REVISION = "09fc542877a84318291aa42dab143a3e2c3db974"
FILES = {
    "LICENSE": "29f44f6af3005961e76e712a8b0f36faf4d8c3d8e2592ca191876154adff2179",
    "netlist_6502.h": "7a5a28f64a0d464d18faecd3d715d96549bc5da8f05e6f468ef3dae97ef0f340",
    "netlist_sim.c": "19d1e30504fb13c27d79f8c8f01df5d080b30b621a60a548b1b84c614d7caed2",
    "netlist_sim.h": "fe483a7f43f973dfc388b02410a711ceb5b492ab08970429cc16a7cd0caf70bb",
    "perfect6502.c": "cac56dab1d6a08852361870191d9d5f633450939c14b7e5505e26da78146bbbf",
    "perfect6502.h": "15ab13035b71d5008bd14d993b34656df088d760d18308a7fb64d7b28c53d340",
    "types.h": "484747d5c63f0b4c1c8ed897ea52606bd7521b08f78a469582603e85a678f3bc",
}
destination = Path(__file__).resolve().parents[1] / "work/native/netlist"
destination.mkdir(parents=True, exist_ok=True)
for name, expected in FILES.items():
    target = destination / name
    if target.exists():
        data = target.read_bytes()
    else:
        with urllib.request.urlopen(
            f"https://raw.githubusercontent.com/mist64/perfect6502/{REVISION}/{name}",
            timeout=60,
        ) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"Independent oracle hash mismatch: {name}")
    if not target.exists():
        target.write_bytes(data)
print(f"Verified perfect6502 {REVISION}: {len(FILES)} unchanged source/license files")
