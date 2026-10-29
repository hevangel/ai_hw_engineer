#!/usr/bin/env python3
"""Pin external SingleStepTests nes6502 traces (decimal-disabled 6502); never derive from RTL."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

REVISION = "2f6980a2d95757486c7bee24355c360e40e2a224"
BASE = f"https://raw.githubusercontent.com/SingleStepTests/65x02/{REVISION}/nes6502/v1"
ROOT = Path(__file__).resolve().parents[1]


def retrieve(opcode, directory):
    path = directory / f"{opcode}.json"
    if not path.exists():
        with urllib.request.urlopen(f"{BASE}/{opcode}.json", timeout=120) as response:
            body = response.read()
        json.loads(body)  # Reject HTTP error pages before caching.
        path.write_bytes(body)
    return opcode, hashlib.sha256(path.read_bytes()).hexdigest()


def touches_chip_registers(case):
    """The vectors assume flat RAM. On the 2A03, $4015 reads are internal and
    $4000-$4017 writes reach the APU/DMA, so those records do not describe the
    chip and are excluded (and counted) rather than patched."""
    for address, _value, direction in case["cycles"]:
        if direction == "read" and address == 0x4015:
            return True
        if direction == "write" and 0x4000 <= address <= 0x4017:
            return True
    return False


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
    parser.add_argument("--per-opcode", type=int, default=1000, help="0 selects every available case")
    args = parser.parse_args()
    opcodes = [f"{n:02x}" for n in range(256)]
    directory = ROOT / "work" / "cpu" / "inputs" / REVISION
    directory.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        hashes = dict(pool.map(lambda opcode: retrieve(opcode, directory), opcodes))
    count = excluded = 0
    destination = ROOT / "work" / "cpu" / "vectors.txt"
    body = []
    for opcode in opcodes:
        cases = json.loads((directory / f"{opcode}.json").read_bytes())
        if args.per_opcode:
            cases = cases[:args.per_opcode]
        for index, case in enumerate(cases):
            if touches_chip_registers(case):
                excluded += 1
                continue
            body.append((opcode, index, case))
    with destination.open("w", newline="\n") as output:
        output.write(f"{len(body)}\n")
        for opcode, index, case in body:
            emit_case(output, opcode, index, case)
            count += 1
    manifest = {"revision": REVISION, "source": BASE, "sha256": hashes, "cases": count,
                "excluded_register_cases": excluded, "per_opcode": args.per_opcode}
    (destination.parent / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"External nes6502 vectors: {count} cases, {excluded} excluded (chip registers) -> {destination}")


if __name__ == "__main__":
    main()
