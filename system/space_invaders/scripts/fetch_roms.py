#!/usr/bin/env python3
"""Fetch the original Taito Space Invaders ROM set from the immutable PCjs
archive at a pinned git revision; verify container blob hashes and ROM
CRC-32 values against the canonical MAME driver checksums; build the
$readmemh image. The copyrighted ROM bytes never enter Git (work/ only).

Download targets are compile-time constants validated against an explicit
scheme/host allowlist before any request is made.
"""
import hashlib
import json
import re
import urllib.parse
import urllib.request
import zlib
from pathlib import Path

REPO = "jeffpar/pcjs"
REVISION = "7d1795cf263f7f63bb6df3cef616a17fa0068f75"
ALLOWED_SCHEMES = {"https"}
ALLOWED_HOSTS = {"raw.githubusercontent.com"}

# (path in pcjs, git blob sha1 of the json5, ROM crc32, load address)
ROMS = [
    ("machines/arcade/invaders/rom/INVADERS-H.json5",
     "ac6e1ebb9231e1be470ef5e67663a4d66948d29a", 0x734F5AD8, 0x0000),
    ("machines/arcade/invaders/rom/INVADERS-G.json5",
     "9883e727ecbc3d3a780b0c6e831c459d5a94569e", 0x6BFACA4A, 0x0800),
    ("machines/arcade/invaders/rom/INVADERS-F.json5",
     "2b86957ed674a30a8edbc35a4ad0ccbcb127a9d1", 0x0CCEAD96, 0x1000),
    ("machines/arcade/invaders/rom/INVADERS-E.json5",
     "f3fd6dd261c2914cf11c693deaa8b5852efb13be", 0x14E538B0, 0x1800),
]


def fetch(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
        raise SystemExit(f"download target rejected by allowlist: {url}")
    request = urllib.request.Request(url, headers={"User-Agent": "ai-hw-engineer"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def main():
    work = Path(__file__).resolve().parents[1] / "work"
    work.mkdir(exist_ok=True)
    image = bytearray(8192)
    manifest = []
    for path, blob, crc, base in ROMS:
        raw = work.joinpath("reference", Path(path).name)
        raw.parent.mkdir(exist_ok=True)
        if not raw.exists():
            raw.write_bytes(fetch(f"https://raw.githubusercontent.com/{REPO}/{REVISION}/{path}"))
        content = raw.read_bytes()
        # SHA-1 here is the git blob-object identity format (not a security
        # primitive): it pins the exact archived file, as in the ibm_pc
        # system. ROM integrity itself is the CRC-32 cross-check below plus
        # the SHA-256 recorded in the manifest.
        if hashlib.sha1(f"blob {len(content)}\0".encode() + content).hexdigest() != blob:
            raise SystemExit(f"pinned archive blob mismatch: {path}")
        text = re.sub(r"//[^\n]*", "", content.decode())
        text = re.sub(r"0x[0-9a-fA-F]+", lambda m: str(int(m[0], 16)), text)
        text = re.sub(r",\s*([\]}])", r"\1", text)
        data = bytes(json.loads(text)["bytes"])
        if len(data) != 2048 or (zlib.crc32(data) & 0xFFFFFFFF) != crc:
            raise SystemExit(f"ROM integrity mismatch: {path}")
        image[base:base + 2048] = data
        manifest.append({"file": Path(path).name, "bytes": len(data),
                         "crc32": f"{crc:08x}",
                         "sha256": hashlib.sha256(data).hexdigest()})
    (work / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # $readmemh image: two hex digits per byte, one byte per line.
    (work / "si_rom.hex").write_text(
        "".join(f"{byte:02x}\n" for byte in image))
    print(f"Space Invaders ROM verified and staged: {len(image)} bytes "
          f"(4x2KiB, CRCs match the canonical MAME driver values)")


if __name__ == "__main__":
    main()
