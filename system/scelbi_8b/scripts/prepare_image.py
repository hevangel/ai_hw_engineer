#!/usr/bin/env python3
"""Compose a full 16 KiB SCELBI 8B memory image with SCELBAL.

SCELBAL loads at octal 0100 (hex 0x0040), following SIMH's SCELBI guide, and
a JMP at address 0 reaches it on reset (the 8008 fetches address 0 twice, so
the jump occupies 0x0000-0x0002). Remaining bytes are zero (RAM).
"""
from pathlib import Path
import sys

source, target = Path(sys.argv[1]), Path(sys.argv[2])
data = source.read_bytes()
if len(data) != 11942:
    raise SystemExit(f"unexpected SCELBAL image size {len(data)} (SIMH's guide loads 11942)")
memory = bytearray(16384)
memory[0:3] = b"\x44\x40\x00"          # JMP 0040 (octal 0100)
memory[0x40:0x40 + len(data)] = data
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("".join(f"{byte:02x}\n" for byte in memory), encoding="ascii")
print(f"Composed {source} -> {target}")
