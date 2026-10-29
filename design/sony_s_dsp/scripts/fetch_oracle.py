#!/usr/bin/env python3
"""Pin the independent S-DSP reference model into the ignored work/ folder:
blargg's cycle-accurate SPC_DSP (snes_spc 0.9.0) as carried by snes9x.
The gate in scripts/run_oracle.sh compiles it next to the RTL; the RTL was
written from a different code base (ares), so the two share only the public
algorithm. Also checks the generated gaussian table against the hardware
dump embedded in that file."""
import hashlib
from pathlib import Path
import re
import shutil
import sys
import urllib.request

REVISION = "1bcc369e89f08243e0a462882fb1f3e42e51de3a"
BASE = f"https://raw.githubusercontent.com/snes9xgit/snes9x/{REVISION}/apu/bapu/dsp"
FILES = ["SPC_DSP.cpp", "SPC_DSP.h", "blargg_common.h", "blargg_config.h",
         "blargg_endian.h", "blargg_source.h"]
ROOT = Path(__file__).resolve().parents[1]


def main():
    dest = ROOT / "work" / "oracle" / "apu" / "bapu" / "dsp"
    dest.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        path = dest / name
        if not path.exists():
            with urllib.request.urlopen(f"{BASE}/{name}", timeout=60) as response:
                path.write_bytes(response.read())
        print(f"{name} sha256={hashlib.sha256(path.read_bytes()).hexdigest()}")
    shutil.copy(ROOT / "tb" / "oracle_shim" / "snes9x.h", ROOT / "work" / "oracle" / "snes9x.h")

    text = (dest / "SPC_DSP.cpp").read_text()
    body = text[text.index("gauss [512]"):]
    body = body[body.index("{") + 1:body.index("}")]
    dump = [int(v) for v in re.findall(r"-?\d+", body)]
    svh = (ROOT / "src" / "sony_s_dsp_gauss.svh").read_text()
    ours = [int(v) for v in re.findall(r"9'd\d+: gauss = 11'd(\d+);", svh)]
    if len(dump) != 512 or ours != dump:
        sys.exit("FAIL: generated gaussian table differs from the hardware dump")
    print("PASS: gaussian table matches the 512-entry hardware dump")


if __name__ == "__main__":
    main()
