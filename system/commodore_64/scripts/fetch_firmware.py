#!/usr/bin/env python3
"""Fetch and verify the original Commodore 64 ROMs into work/ (not committed).

Each image is tried from zimmers.net (the source the repository's 6526 suite
already pins) and then from the VICE source mirror at a pinned commit. Both
must produce the same SHA-256, which matches MAME's canonical SHA-1 for the
part number. Firmware copyright remains with its owners.
"""
from pathlib import Path
import hashlib
import urllib.request

VICE = ("https://raw.githubusercontent.com/VICE-Team/svn-mirror/"
        "d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/data/C64/")
ZIMMERS = "https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64/"
ROMS = {
    # name: (zimmers file, VICE file, size, sha256, MAME sha1)
    "basic": ("basic.901226-01.bin", "basic-901226-01.bin", 8192,
              "89878cea0a268734696de11c4bae593eaaa506465d2029d619c0e0cbccdfa62d",
              "79015323128650c742a3694c9429aa91f355905e"),
    "kernal": ("kernal.901227-03.bin", "kernal-901227-03.bin", 8192,
               "83c60d47047d7beab8e5b7bf6f67f80daa088b7a6a27de0d7e016f6484042721",
               "1d503e56df85a62fee696e7618dc5b4e781df1bb"),
    "chargen": ("characters.901225-01.bin", "chargen-901225-01.bin", 4096,
                "fd0d53b8480e86163ac98998976c72cc58d5dd8eb824ed7b829774e74213b420",
                "adc7c31e18c7c7413d54802ef2f4193da14711aa"),
}
work = Path(__file__).resolve().parents[1] / "work"
work.mkdir(parents=True, exist_ok=True)


def download(urls):
    errors = []
    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                return response.read()
        except OSError as error:
            errors.append(f"{url}: {error}")
    raise SystemExit("cannot fetch ROM:\n  " + "\n  ".join(errors))


for name, (zimmers, vice, size, sha256, sha1) in ROMS.items():
    target = work / f"{name}.bin"
    data = target.read_bytes() if target.exists() else download([ZIMMERS + zimmers, VICE + vice])
    if len(data) != size or hashlib.sha256(data).hexdigest() != sha256 \
            or hashlib.sha1(data).hexdigest() != sha1:
        raise SystemExit(f"{name}: ROM hash mismatch")
    target.write_bytes(data)
    (work / f"{name}.hex").write_text("".join(f"{b:02x}\n" for b in data))
    print(f"Verified {vice} ({size} bytes, SHA-1 {sha1})")
