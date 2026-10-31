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
    "cia1ta.prg": "8569c86efe3c35334a99f3cc0401ffc4fc6b8562c52aedaad27657c7e1854db2",
    "cia1ta.s": "87f8c68b513875e20a68e2456938a9a3a80809be5fb44ec8c446ac544bfc175f",
    "cia1tb.prg": "23139558a34b1ba6f1ecbb7d2e9ffe8ff0feca0ba400d035ff865c917d9d0a7b",
    "cia1tb.s": "2418e2e94afc41eba49358ca452d1e70213b1c85b53e1c8f132d4699cb96bb0c",
    "cia1tab.prg": "b6d121755d250754101420a9c0c12709274eff8d1e4448f10f701a9593ad49c8",
    "cia1tab.s": "ecdad546861e7b67bd9e3b081d6ebdbd9fe57afade7c2861fc60fc93eaecd638",
    "cia1tb123.prg": "4dba7cd385dbfa06d8b75a15dce61104602c880a1c65d0e4958a15c0cc0f43d6",
    "cia1tb123.s": "f7c3f7872cb0a2193c57c48d873cd3318ecd6b61b5f205407e85d52033bb33ca",
    "cia2pb6.prg": "4bbd774244f9dc397d7832eca3c3e1e1c812ca1c3e3c94b7c1fc2373ac5ca495",
    "cia2pb6.s": "40792a8a56243b5259a4d4d669b76c2a69dfd9921d8f84b952f1d96704511031",
    "cia2pb7.prg": "3e9f0e8381fa22c01094949d59c10eff8705862ec189244e348f205c64b13de4",
    "cia2pb7.s": "9d2899646b2e83cf1c454fae1236f59ee7fdadd663dd4e9453b3c0b899b785b2",
    "cia2ta.prg": "27f89cdb086ce99a0d05218b0faef6e2d4dd1d1155ca25c77e86550c7b1643df",
    "cia2ta.s": "8952f45d950967725990c9192babc9b058e1a032ba52d95ca0e47575a88d547f",
    "cia2tb.prg": "ec3750353bc7c0f3eeb3a8148fe259f069982224121374486a0f54b1b440404b",
    "cia2tb.s": "3f0193d31c408a833aecf41e274962fca5a49cdeb26998cc141538c25df29022",
    "cia2tb123.prg": "18a738f7c8ff4da3b057cddb2f5d03572871994453b89294d0609ea8ef24a016",
    "cia2tb123.s": "c71dced51c489168f59ca4f87fada46332e2c91d8cb309c3e8cc54019f1d868a",
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
def fetch_verified(name, url, expected):
    target = directory / name.replace("/", "-")
    if target.exists():
        data = target.read_bytes()
    else:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f"Original Lorenz software hash mismatch: {name}")
    if not target.exists():
        target.write_bytes(data)
for name, expected in FILES.items():
    fetch_verified(name, ROOT + name, expected)
fetch_verified("kernal.901227-03.bin",
    "https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64/kernal.901227-03.bin",
    "83c60d47047d7beab8e5b7bf6f67f80daa088b7a6a27de0d7e016f6484042721")
print(f"Verified unchanged public-domain Lorenz CIA software at VICE SVN r{REVISION}")
print("Verified original Commodore 901227-03 KERNAL; firmware copyright remains with its owners")
