#!/usr/bin/env python3
"""Pin external SingleStepTests NMOS input/state/bus traces, never derive from RTL."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

REVISION = "2f6980a2d95757486c7bee24355c360e40e2a224"
BASE = f"https://raw.githubusercontent.com/SingleStepTests/65x02/{REVISION}/6502/v1"
ROOT = Path(__file__).resolve().parents[1]
# Documented NMOS opcode table (MOS programming manual), independent of the RTL.
DOCUMENTED = """
00 01 05 06 08 09 0a 0d 0e 10 11 15 16 18 19 1d 1e
20 21 24 25 26 28 29 2a 2c 2d 2e 30 31 35 36 38 39 3d 3e
40 41 45 46 48 49 4a 4c 4d 4e 50 51 55 56 58 59 5d 5e
60 61 65 66 68 69 6a 6c 6d 6e 70 71 75 76 78 79 7d 7e
81 84 85 86 88 8a 8c 8d 8e 90 91 94 95 96 98 99 9a 9d
a0 a1 a2 a4 a5 a6 a8 a9 aa ac ad ae b0 b1 b4 b5 b6 b8 b9 ba bc bd be
c0 c1 c4 c5 c6 c8 c9 ca cc cd ce d0 d1 d5 d6 d8 d9 dd de
e0 e1 e4 e5 e6 e8 e9 ea ec ed ee f0 f1 f5 f6 f8 f9 fd fe
""".split()


def retrieve(opcode, directory):
    path = directory / f"{opcode}.json"
    if not path.exists():
        with urllib.request.urlopen(f"{BASE}/{opcode}.json", timeout=90) as response:
            body = response.read()
        json.loads(body)  # Reject HTTP error pages before caching.
        path.write_bytes(body)
    body = path.read_bytes()
    return opcode, hashlib.sha256(body).hexdigest()


def emit_case(output, opcode, index, case):
    output.write(f"{int(opcode, 16)} {index}\n")
    for section in ("initial", "final"):
        state = case[section]
        output.write(" ".join(str(state[k]) for k in ("pc", "a", "x", "y", "s", "p")) + "\n")
        memory = state["ram"]
        output.write(f"{len(memory)}\n")
        for address, value in memory:
            output.write(f"{address} {value}\n")
    output.write(f"{len(case['cycles'])}\n")
    for address, value, direction in case["cycles"]:
        if direction not in ("read", "write"):
            raise ValueError(f"Unknown bus direction: {direction}")
        output.write(f"{address} {value} {int(direction == 'write')}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--opcodes", default="documented", help="documented, all, or comma-separated hex bytes")
    parser.add_argument("--per-opcode", type=int, default=100, help="0 selects every available case")
    args = parser.parse_args()
    opcodes = DOCUMENTED if args.opcodes == "documented" else (
        [f"{n:02x}" for n in range(256)] if args.opcodes == "all" else args.opcodes.lower().split(","))
    opcodes = [f"{int(opcode, 16):02x}" for opcode in opcodes]
    if args.per_opcode < 0 or len(set(opcodes)) != len(opcodes):
        parser.error("Nonnegative case limit and distinct opcodes required")
    directory = ROOT / "work" / "native" / "inputs" / REVISION
    directory.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        hashes = dict(pool.map(lambda opcode: retrieve(opcode, directory), opcodes))
    selected = []
    for opcode in opcodes:
        cases = json.loads((directory / f"{opcode}.json").read_bytes())
        selected.append((opcode, cases if args.per_opcode == 0 else cases[:args.per_opcode]))
    count = sum(len(cases) for _, cases in selected)
    destination = ROOT / "work" / "native" / "vectors.txt"
    with destination.open("w", newline="\n") as output:
        output.write(f"{count}\n")
        for opcode, cases in selected:
            for index, case in enumerate(cases):
                emit_case(output, opcode, index, case)
    manifest = {"revision": REVISION, "source": BASE, "sha256": hashes,
                "cases": count, "per_opcode": args.per_opcode}
    (destination.parent / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"External NMOS vectors: {len(opcodes)} opcodes, {count} cases -> {destination}")


if __name__ == "__main__":
    main()
