#!/usr/bin/env python3
"""Pin the external SingleStepTests 65816 records and convert them to the
plain-text form read by tb/cpu_vector_test.cpp. Expected values come only
from the external files; nothing is derived from the RTL."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

REVISION = "307c63f5673c8c6b861c52f71ddb89212a227480"
BASE = f"https://raw.githubusercontent.com/SingleStepTests/65816/{REVISION}/v1"
ROOT = Path(__file__).resolve().parents[1]
FLAGS = "dpvremxl"   # bus-signal characters in record order
STATE_KEYS = ("pc", "s", "p", "a", "x", "y", "dbr", "d", "pbr", "e")


def retrieve(name, directory):
    path = directory / f"{name}.json"
    if not path.exists():
        with urllib.request.urlopen(f"{BASE}/{name}.json", timeout=300) as response:
            body = response.read()
        json.loads(body)  # Reject HTTP error pages before caching.
        path.write_bytes(body)
    return name, hashlib.sha256(path.read_bytes()).hexdigest()


def signals(text):
    """Bit n is set when character n of the record is the active letter
    ('r' for the read/write position, so a clear bit 3 means a write)."""
    if len(text) != 8:
        raise ValueError(f"bad signal string {text!r}")
    bits = 0
    for n, (char, active) in enumerate(zip(text, FLAGS)):
        if char == active:
            bits |= 1 << n
        elif not (char == "-" or (n == 3 and char == "w")):
            raise ValueError(f"bad signal string {text!r}")
    return bits


def emit_case(output, name, index, case):
    output.write(f"{int(name[:2], 16)} {int(name[3] == 'e')} {index}\n")
    for section in ("initial", "final"):
        state = case[section]
        output.write(" ".join(str(state[k]) for k in STATE_KEYS) + "\n")
        output.write(f"{len(state['ram'])}\n")
        for address, value in state["ram"]:
            output.write(f"{address} {value}\n")
    output.write(f"{len(case['cycles'])}\n")
    for address, value, text in case["cycles"]:
        # A halted WAI/STP cycle has no address: written as -1.
        output.write(f"{-1 if address is None else address} {-1 if value is None else value} "
                     f"{0 if address is None else signals(text)}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--per-file", type=int, default=500, help="0 selects every case")
    parser.add_argument("--opcodes", default="", help="comma-separated hex opcodes (default all)")
    args = parser.parse_args()
    opcodes = [o.strip().lower() for o in args.opcodes.split(",") if o.strip()] or \
              [f"{n:02x}" for n in range(256)]
    names = [f"{o}.{m}" for o in opcodes for m in ("n", "e")]
    directory = ROOT / "work" / "cpu" / "inputs" / REVISION
    directory.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=6) as pool:
        hashes = dict(pool.map(lambda name: retrieve(name, directory), names))
    destination = ROOT / "work" / "cpu" / "vectors.txt"
    count = 0
    # Stream one file at a time; the full set does not fit in memory.
    sizes = {}
    for name in names:
        total = len(json.loads((directory / f"{name}.json").read_bytes()))
        sizes[name] = min(total, args.per_file) if args.per_file else total
    with destination.open("w", newline="\n") as output:
        output.write(f"{sum(sizes.values())}\n")
        for name in names:
            cases = json.loads((directory / f"{name}.json").read_bytes())[:sizes[name]]
            for index, case in enumerate(cases):
                emit_case(output, name, index, case)
                count += 1
    manifest = {"revision": REVISION, "source": BASE, "sha256": hashes, "cases": count,
                "per_file": args.per_file}
    (destination.parent / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"External 65816 vectors: {count} cases from {len(names)} files -> {destination}")


if __name__ == "__main__":
    main()
