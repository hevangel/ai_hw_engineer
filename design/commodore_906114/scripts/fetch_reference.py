#!/usr/bin/env python3
"""Fetch the pinned, unchanged VICE sources used as the PLA oracle."""
from pathlib import Path
import hashlib
import urllib.request

COMMIT = "d928b850b7ef4c1b1826a6efd175d8eaa80344d8"
ROOT = f"https://raw.githubusercontent.com/VICE-Team/svn-mirror/{COMMIT}/vice/src/"
FILES = {
    "c64/c64mem.c": "29c1c55e4c27eca478ba67405bfc305bdd173951c0a52bf33a85406e189fe6b1",
    "c64/c64meminit.c": "b50b0117133578892be3e2435761690de0f811b6724721bcd83dbb8c06781b19",
    "vicii/vicii.c": "ccdf61101d9aede815b624cfae12871e92498c40ae223c7a0ed1ec2ce2223cc1",
}
directory = Path(__file__).resolve().parents[1] / "work/vice"
directory.mkdir(parents=True, exist_ok=True)
for name, expected in FILES.items():
    target = directory / Path(name).name
    data = target.read_bytes() if target.exists() else None
    if data is None:
        with urllib.request.urlopen(ROOT + name, timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"VICE reference hash mismatch: {name}")
    target.write_bytes(data)
print(f"Verified unchanged VICE sources at svn-mirror {COMMIT[:12]}")
