#!/usr/bin/env python3
"""Convert the Shooting Stars BASIC listing to a typed-input hex image.

SCELBAL recognizes upper case only and expects carriage returns from the
console (there is no line-feed handling in program entry), so the listing is
upper-cased and every newline becomes CR. Output is one hex byte per line for
$readmemh.
"""
from pathlib import Path
import sys

source, target = Path(sys.argv[1]), Path(sys.argv[2])
text = source.read_text(encoding="ascii").upper().replace("\r\n", "\n").replace("\n", "\r")
data = text.encode("ascii")
if len(data) > 4095:
    raise SystemExit(f"program image too large: {len(data)} bytes")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("".join(f"{b:02x}\n" for b in data) + "ff\n", encoding="ascii")
print(f"Prepared {source} -> {target} ({len(data)} bytes)")
