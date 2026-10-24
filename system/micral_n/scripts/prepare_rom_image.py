#!/usr/bin/env python3
"""Compose a full 16 KiB Micral N memory image from the recovered ROMs.

Places the boot EPROM at page 0 (0x0000-0x00FF) and the MIC-01 monitor ROM
at 0x3800-0x3FFF, matching the restored machine's ROM map (see
spec/reference/micral_rom_recovery.md). Remaining bytes are zero, which the
boot treats as RAM.
"""
from pathlib import Path
import sys

def load(path, expected, what):
    data = Path(path).read_bytes()
    if len(data) != expected:
        raise SystemExit(f"{what}: expected {expected} bytes, found {len(data)}")
    return data

bootloader, monitor = sys.argv[1], sys.argv[2]
target = Path(sys.argv[3])
memory = bytearray(16384)
memory[0x0000:0x0100] = load(bootloader, 256, "bootloader")
memory[0x3800:0x4000] = load(monitor, 2048, "monitor")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("".join(f"{byte:02x}\n" for byte in memory), encoding="ascii")
print(f"Composed {bootloader} + {monitor} -> {target}")
