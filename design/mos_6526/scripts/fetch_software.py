#!/usr/bin/env python3
"""Verify unchanged public-domain Lorenz CIA programs and original sources."""
from pathlib import Path
import hashlib
import urllib.request

REVISION = 45243
ROOT = f"https://svn.code.sf.net/p/vice-emu/code/!svn/bc/{REVISION}/testprogs/general/Lorenz-2.15/src/"
FILES = {
    "cia1pb6.prg": "322ba2e7ada1bb76ef72b916aa87222d0294ac0094e3fb0a6ab291543b537585",
    "cia1pb6.s": "089380a5e4c807cc3d3f6a02a95fc285c741dc25b7c12d96977880dfc5905fb2",
    "cia1pb7.prg": "2d92273c14051528cb654bd00c0e10b83d3a336293f51e26b84baf0088fdb320",
    "cia1pb7.s": "22f268fa75d496575fb7d00ad0ef6b702f21e4e013e54e712b3c1f173e5be2a3",
    "common/common.asm": "5b0a3e74ba5da2852211bca5d832acace8777e6206ad44601a537c175a627427",
    "common/startup.asm": "9e17fd610e55e76d08f15a256d348fee5fa7c42c17fff6e5abba7d8f9462eefa",
    "common/print.asm": "719dec5516cfb6ab5f91fca3d7dca9790316bdb622bca8c66a14bfabadfd130b",
    "common/printhb.asm": "5671e6a1b156d1d687855a13309c79dcba920a1aa7ad856ffdcc3e80ca761343",
    "common/target.inc": "7cb520038c24aadfed6fd1f975b98da11260bcedd73b18ad15f2150fd3301a3a",
    "common/waitkey.asm": "c89661638946c3406cb7f9486ed9628f3fe6626d75d22460a8ab966314edaa97",
    "common/waitborder.asm": "3179b9f62b9cc1c624df3cfd79f6afa1518532b78803dcb4aec10e86933307cc",
    "Makefile": "744fb2fa86ff93771018be8c3739899360c39c6593e005fcfb58ce577fc19828",
}
directory = Path(__file__).resolve().parents[1] / "work/lorenz"
directory.mkdir(parents=True, exist_ok=True)
for name, expected in FILES.items():
    target = directory / name.replace("/", "-")
    if target.exists():
        data = target.read_bytes()
    else:
        with urllib.request.urlopen(ROOT + name, timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"Original Lorenz software hash mismatch: {name}")
    if not target.exists():
        target.write_bytes(data)
print(f"Verified unchanged public-domain Lorenz CIA software at VICE SVN r{REVISION}")
