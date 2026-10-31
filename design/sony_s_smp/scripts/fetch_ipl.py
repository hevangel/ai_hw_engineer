#!/usr/bin/env python3
"""Pin the 64-byte S-SMP IPL ROM image into the ignored work/ folder.
The bytes are Sony's mask ROM, so they are not committed. They are read
from a pinned snes9x source file and written as work/ipl.hex."""
import hashlib
from pathlib import Path
import re
import urllib.request

REVISION = "1bcc369e89f08243e0a462882fb1f3e42e51de3a"
URL = f"https://raw.githubusercontent.com/snes9xgit/snes9x/{REVISION}/apu/bapu/smp/iplrom.cpp"
ROOT = Path(__file__).resolve().parents[1]


def main():
    with urllib.request.urlopen(URL, timeout=60) as response:
        text = response.read().decode()
    body = text[text.index("iplrom[64]"):]
    body = body[body.index("{") + 1:body.index("}")]
    body = re.sub(r"//[^\n]*", "", body)
    data = bytes(int(v, 16) for v in re.findall(r"0x([0-9a-fA-F]{2})", body))
    if len(data) != 64 or data[62:64] != b"\xc0\xff":
        raise SystemExit("unexpected IPL ROM image (length or reset vector)")
    out = ROOT / "work" / "ipl.hex"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(f"{b:02x}\n" for b in data))
    print(f"IPL ROM: {out} sha256={hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
