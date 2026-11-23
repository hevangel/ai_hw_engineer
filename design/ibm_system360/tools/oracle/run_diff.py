#!/usr/bin/env python3
"""Differential runner: S/360 RTL against an independent emulator.

Runs on the host (needs python3 and node). The RTL side is executed inside the
project image through docker, because only the image has Verilator.

    python tools/oracle/run_diff.py [--rtl-image ai-hw-engineer:latest]

The emulator is not part of this repository: it lives in the ignored work/ tree
and is located through ORACLE_ROOT (default
<repo>/work/s360/oracle/s360-model30-v01-main). URL, commit and licence status
are recorded in spec/sources.md.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN = HERE.parent.parent
REPO = DESIGN.parent.parent
WORK = DESIGN / "work" / "oracle"

sys.path.insert(0, str(HERE))
from cases import CASES, build_image, compare, parse_dump  # noqa: E402
from random_cases import make_cases  # noqa: E402


def oracle_root():
    env = os.environ.get("ORACLE_ROOT")
    root = Path(env) if env else REPO / "work" / "s360" / "oracle" / "s360-model30-v01-main"
    if not (root / "src" / "core.js").exists():
        raise SystemExit(
            "independent emulator not found at %s\n"
            "Set ORACLE_ROOT, or fetch it as described in plans/oracle_plan.md." % root)
    return root


def host_to_container(path: Path):
    return "/work/" + str(path.relative_to(REPO)).replace("\\", "/")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rtl-image", default="ai-hw-engineer:latest")
    ap.add_argument("--random", type=int, default=24,
                    help="number of randomised cases (0 disables)")
    args = ap.parse_args()

    root = oracle_root()
    WORK.mkdir(parents=True, exist_ok=True)

    cases = list(CASES) + (make_cases(args.random) if args.random else [])
    manifest = []
    for case in cases:
        out_dir = WORK / case["name"]
        out_dir.mkdir(parents=True, exist_ok=True)
        image = build_image(case)
        prog = out_dir / "prog.hex"
        prog.write_text("\n".join(f"{w:08X}" for w in image) + "\n")
        manifest.append(dict(name=case["name"], prog=host_to_container(prog),
                             words=len(image), steps=case["steps"],
                             out=host_to_container(out_dir / "rtl.txt")))

    manifest_path = WORK / "manifest.json"
    manifest_path.write_text(json.dumps(manifest))

    print(f"oracle: {root}")
    r = subprocess.run(["docker", "run", "--rm", "-v", f"{REPO}:/work", "-w", "/work",
                        args.rtl_image, "python3",
                        host_to_container(HERE / "rtl_dump.py"),
                        host_to_container(manifest_path)],
                       text=True)
    if r.returncode != 0:
        raise SystemExit("RTL side failed")

    failures = 0
    env = dict(os.environ, ORACLE_ROOT=str(root))
    for case in cases:
        out_dir = WORK / case["name"]
        ref_out = out_dir / "ref.txt"
        r = subprocess.run(["node", str(HERE / "js_run.js"), str(out_dir / "prog.hex"),
                            str(len(build_image(case))), str(case["steps"]), str(ref_out)],
                           capture_output=True, text=True, env=env)
        if r.returncode != 0:
            print(r.stdout[-1500:])
            print(r.stderr[-1500:])
            raise SystemExit(f"emulator run failed for {case['name']}")

        problems = compare(parse_dump(out_dir / "rtl.txt"), parse_dump(ref_out),
                          ignore_cc=case.get("ignore_cc", False))
        if problems:
            failures += 1
            print(f"FAIL {case['name']}: {case['note']}")
            for p in problems:
                print("   " + p)
        elif case.get("ignore_cc"):
            print(f"PASS {case['name']}: {case['note']} "
                  "(CC ignored: reference sets it on NC/OC/XC, p. 55)")
        else:
            print(f"PASS {case['name']}: {case['note']}")

    print(f"\n{len(cases) - failures}/{len(cases)} cases agree with the independent emulator")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
