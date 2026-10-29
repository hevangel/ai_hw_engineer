#!/usr/bin/env python3
"""Pin the external SingleStepTests spc700 records and convert them to the
plain-text form read by tb/cpu_vector_test.cpp. Expected values come only
from the external files; nothing is derived from the RTL."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

REVISION = "67d15f492b2740964abd4efd1229e0ec9c342228"
BASE = f"https://raw.githubusercontent.com/SingleStepTests/spc700/{REVISION}/v1"
ROOT = Path(__file__).resolve().parents[1]
STATE_KEYS = ("pc", "a", "x", "y", "sp", "psw")
KINDS = {"read": 0, "write": 1, "wait": 2}


def retrieve(name, directory):
    path = directory / f"{name}.json"
    if not path.exists():
        with urllib.request.urlopen(f"{BASE}/{name}.json", timeout=300) as response:
            body = response.read()
        json.loads(body)  # Reject HTTP error pages before caching.
        path.write_bytes(body)
    return name, hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--per-opcode", type=int, default=0, help="0 selects every case")
    args = parser.parse_args()
    names = [f"{n:02x}" for n in range(256)]
    directory = ROOT / "work" / "cpu" / "inputs"
    directory.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=6) as pool:
        hashes = dict(pool.map(lambda name: retrieve(name, directory), names))
    destination = ROOT / "work" / "cpu" / "vectors.txt"
    body = []
    for name in names:
        cases = json.loads((directory / f"{name}.json").read_bytes())
        body.extend((name, i, c) for i, c in enumerate(cases[:args.per_opcode or None]))
    with destination.open("w", newline="\n") as out:
        out.write(f"{len(body)}\n")
        for name, index, case in body:
            out.write(f"{int(name, 16)} {index}\n")
            for section in ("initial", "final"):
                state = case[section]
                out.write(" ".join(str(state[k]) for k in STATE_KEYS) + "\n")
                out.write(f"{len(state['ram'])}\n")
                for address, value in state["ram"]:
                    out.write(f"{address} {value}\n")
            out.write(f"{len(case['cycles'])}\n")
            for address, value, kind in case["cycles"]:
                out.write(f"{-1 if address is None else address} {-1 if value is None else value} "
                          f"{KINDS[kind]}\n")
    manifest = {"revision": REVISION, "source": BASE, "sha256": hashes, "cases": len(body)}
    (destination.parent / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"External spc700 vectors: {len(body)} cases -> {destination}")


if __name__ == "__main__":
    main()
