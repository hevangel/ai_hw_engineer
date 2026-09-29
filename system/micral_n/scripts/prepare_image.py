#!/usr/bin/env python3
"""Convert a complete 16 KiB Micral memory image to Verilog hex format."""
from pathlib import Path
import sys

source, target = map(Path, sys.argv[1:3])
data = source.read_bytes()
if len(data) != 16384:
    raise SystemExit(f"expected 16384 bytes, found {len(data)}")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("".join(f"{byte:02x}\n" for byte in data), encoding="ascii")
print(f"Prepared {source} -> {target}")
