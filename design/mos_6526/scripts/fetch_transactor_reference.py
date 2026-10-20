#!/usr/bin/env python3
"""Pin original detector/firmware and unchanged independent CIA source."""
from pathlib import Path
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "work"
SVN = "https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/"
FILES = {
    "ciatest64.bas": "4b3bf50de8f35ac2f231641ae3e3e28e1cc0c6685fd64b5c8f1b0d86b07fd93f",
    "ciatest64.prg": "6d9149d5cbd26a14c36af32c4779df600e199364c19da299560ee45c95230eb4",
    "readme.txt": "5a666a8bbd29ba45f5ed1bc36bf27c2872b33fe1647bf3f9052044e9740db291",
    "Makefile": "6209e27c82f5df1e1400f8a12523bbe66cb2fc6387b0772ece4e5420d9f30f7a",
}
def verify(relative, url, expected):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        data = path.read_bytes()
    else:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"Independent Transactor reference hash mismatch: {relative}")
    if not path.exists():
        path.write_bytes(data)
for name, expected in FILES.items():
    verify("transactor/" + name, SVN + name, expected)
verify("transactor/basic.901226-01.bin",
    "https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64/basic.901226-01.bin",
    "89878cea0a268734696de11c4bae593eaaa506465d2029d619c0e0cbccdfa62d")
verify("reference-chips/m6526.h",
    "https://raw.githubusercontent.com/floooh/chips/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6526.h",
    "327a362b9b2235af55c0af712c527bce068633c98f76cdc0c8c4bb35e1d47393")
print("Verified original Transactor detector, BASIC ROM and unchanged zlib-licensed CIA reference")
