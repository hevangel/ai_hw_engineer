#!/usr/bin/env python3
"""Run the RTL side of the differential runner (inside the project image).

Builds the oracle testbench once and dumps architectural state for every case
listed in manifest.json. The host-side orchestrator (run_diff.py) writes the
manifest and the images, then runs this script through docker because only the
image has Verilator.

Usage: python3 tools/oracle/rtl_dump.py <manifest.json>
"""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN = HERE.parent.parent
SRC = DESIGN / "src"
TB = DESIGN / "tb"
WORK = DESIGN / "work" / "oracle"


def build(obj: Path):
    sources = [SRC / "ibm_s360_alu.sv", SRC / "ibm_s360_addr.sv",
               SRC / "ibm_s360_psw.sv", SRC / "ibm_s360_cpu.sv", TB / "tb_oracle.sv"]
    cmd = ["verilator", "--binary", "--timing", "-Wall", "-Wno-UNUSEDSIGNAL",
           "-Wno-BLKSEQ", "-Wno-PROCASSINIT", f"-I{SRC}", "-j", "4",
           "--top-module", "tb_oracle", "--Mdir", str(obj)] + [str(s) for s in sources]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-4000:])
        print(r.stderr[-4000:])
        raise SystemExit("verilator build failed")
    return obj / "Vtb_oracle"


def main():
    manifest = json.loads(Path(sys.argv[1]).read_text())
    WORK.mkdir(parents=True, exist_ok=True)
    binary = build(WORK / "obj")
    for case in manifest:
        out = Path(case["out"])
        prog = Path(case["prog"])
        r = subprocess.run([str(binary), f"+prog={prog}", f"+words={case['words']}",
                            f"+steps={case['steps']}", f"+out={out}"],
                           capture_output=True, text=True, cwd=str(WORK))
        if r.returncode != 0:
            print(r.stdout[-2000:])
            print(r.stderr[-2000:])
            raise SystemExit(f"RTL run failed for {case['name']}")
        print(f"rtl {case['name']}: {out}")


if __name__ == "__main__":
    main()
