#!/usr/bin/env python3
"""Hash-pin original CIA TOD programs and their independently authored tables."""
from pathlib import Path
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "work/tod-independent"
BASE = "https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45953/testprogs/CIA/tod/"
FILES = {
    "read-latch.prg": "4463f023b8b0aa42188929c5fdc9050cbab35dbf8d5f38bea0e4b0df5f88ceed",
    "read-latch.s": "f4fb418435170ffed2815f3bc79429323ee1eaeefdebf9aa9139d28faf31838b",
    "write-stop.prg": "5971936fff65f76696b0e96b5df6c87677908bb464facc69232d64526a84dc6f",
    "write-stop.s": "0d3afab1b6b940924ca03946e3e5cefcddbe5544fe0b6fb78a83b606df28671f",
}
ROOT.mkdir(parents=True, exist_ok=True)
for name, expected in FILES.items():
    path = ROOT / name
    if path.exists():
        data = path.read_bytes()
    else:
        with urllib.request.urlopen(BASE + name, timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"Original TOD test hash mismatch: {name}")
    if not path.exists():
        path.write_bytes(data)
print("Verified original SVN 45953 TOD latch/stop programs and tables")
