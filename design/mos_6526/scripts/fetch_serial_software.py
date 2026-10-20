#!/usr/bin/env python3
"""Verify immutable original hardware-table serial test; never rewrite it."""
from pathlib import Path
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "work/independent"
BASE = "https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45953/testprogs/CIA/shiftregister/"
FILES = {
    "cia-sdr-load.a65": "33777916fe6c84111cd0c18344ccacba5bc8553377cdf358afb0148a415e419f",
    "cia-sdr-load.prg": "d5815f5d086c85c38d0aa534bd3fd07541aac84893fd7c6b5b5d642733fa8c22",
    "readme.txt": "084de351020a67648b8ff4cbd046435538204ce1d72eaa7809fa712aa654a565",
    "cia-sdr-delay.asm": "ed577e457162c0c4d427c15453b01f10bfbd902651486a486e94b93351d184d6",
    "cia-sdr-delay.prg": "8492306ab49fa3e2073888ec4e7f2cde0d597da3677d0517da989b76aa15649b",
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
        raise SystemExit(f"Original serial test hash mismatch: {name}")
    if not path.exists():
        path.write_bytes(data)
print("Verified original SVN 45953 serial delay/load hardware tables and programs")
