#!/usr/bin/env python3
"""Hash-pin original independent VICE timer and license; do not rewrite them."""
from pathlib import Path
import hashlib
import urllib.request
REVISION = "d928b850b7ef4c1b1826a6efd175d8eaa80344d8"
FILES = {
    "ciatimer.c": ("vice/src/core/ciatimer.c", "29a2b799442fed620f40f137b014907b921d22cc7cb9b93494e0b4aac5c67ce0"),
    "ciatimer.h": ("vice/src/core/ciatimer.h", "486e3e8bc08249b71b9277f72403b96eaf8f12ffdc9ab8f44e29f1f7848b32fd"),
    "COPYING": ("vice/COPYING", "b8a2f73f743dc1a51aff23f1aacbca4b868564db52496fa3c0caba755bfd1eaf"),
}
directory = Path(__file__).resolve().parents[1] / "work/reference"
directory.mkdir(parents=True, exist_ok=True)
for name, (source, expected) in FILES.items():
    target = directory / name
    if target.exists():
        data = target.read_bytes()
    else:
        with urllib.request.urlopen(f"https://raw.githubusercontent.com/VICE-Team/svn-mirror/{REVISION}/{source}", timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"External timer source hash mismatch: {name}")
    if not target.exists():
        target.write_bytes(data)
print(f"Verified unchanged VICE timer and GPL license at {REVISION}")
