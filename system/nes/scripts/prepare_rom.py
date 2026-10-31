#!/usr/bin/env python3
"""Convert an iNES file into the $readmemh images and cartridge plusargs the
RTL board expects. Writes <out>.prg.hex / <out>.chr.hex and prints the
simulator argument list as JSON.

usage: prepare_rom.py ROM.nes OUT_PREFIX [--entry HEX]

--entry patches the reset vector (used for nestest's automation entry at
$C000, the documented way to run it without a display).
"""
import json
import sys
from pathlib import Path

SUPPORTED_MAPPERS = {0, 1, 2, 3}


def prepare(rom, prefix, entry=None):
    data = Path(rom).read_bytes()
    if data[:4] != b"NES\x1a":
        raise SystemExit(f"{rom}: not an iNES file")
    prg_size = data[4] * 16384
    chr_size = data[5] * 8192
    flags6, flags7 = data[6], data[7]
    mapper = (flags6 >> 4) | (flags7 & 0xF0)
    if mapper not in SUPPORTED_MAPPERS:
        raise SystemExit(f"{rom}: mapper {mapper} is not implemented by nes_cartridge")
    offset = 16 + (512 if flags6 & 4 else 0)
    prg = bytearray(data[offset:offset + prg_size])
    chr_rom = data[offset + prg_size:offset + prg_size + chr_size]
    if len(prg) != prg_size or len(chr_rom) != chr_size:
        raise SystemExit(f"{rom}: truncated image")
    if entry is not None:
        # The reset vector sits in the last 16 KiB bank; patch it there.
        prg[prg_size - 4] = entry & 0xFF
        prg[prg_size - 3] = entry >> 8
    prefix = Path(prefix)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    prg_hex = prefix.with_name(prefix.name + ".prg.hex")
    chr_hex = prefix.with_name(prefix.name + ".chr.hex")
    prg_hex.write_text("".join(f"{b:02x}\n" for b in prg))
    chr_hex.write_text("".join(f"{b:02x}\n" for b in (chr_rom or bytes(8192))))
    args = [f"+prg={prg_hex}", f"+chr={chr_hex}", f"+mapper={mapper}",
            f"+mirror={flags6 & 1}", f"+chrram={0 if chr_size else 1}",
            f"+prgmask={prg_size - 1}", f"+chrmask={(chr_size or 8192) - 1}"]
    return {"mapper": mapper, "prg": prg_size, "chr": chr_size, "args": args}


def main():
    if len(sys.argv) not in (3, 5) or (len(sys.argv) == 5 and sys.argv[3] != "--entry"):
        raise SystemExit(__doc__)
    entry = int(sys.argv[4], 16) if len(sys.argv) == 5 else None
    print(json.dumps(prepare(sys.argv[1], sys.argv[2], entry)))


if __name__ == "__main__":
    main()
