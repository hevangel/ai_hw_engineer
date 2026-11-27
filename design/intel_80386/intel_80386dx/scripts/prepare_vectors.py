#!/usr/bin/env python3
"""Convert pinned SingleStepTests/80386 real-mode captures to a replay file.

Usage: prepare_vectors.py OUT_DIR [STEM ...]
With no STEM arguments every file in the pinned real-mode subset is used.
Writes OUT_DIR/vectors.bin (consumed by tb/tb_replay.cpp) and
OUT_DIR/vector_manifest.json (provenance, selection and per-file counts).
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sst386  # noqa: E402

NO_VALUE = 0xFFFFFFFF


def all_stems() -> list:
    """Every file of the pinned real-mode subset (listing committed beside
    this script, generated from the pinned upstream tree)."""
    listing = pathlib.Path(__file__).resolve().parent / "sst386_real_mode_files.txt"
    return [line.strip() for line in listing.read_text().splitlines() if line.strip()]


def final_regs(test: dict) -> list:
    regs = dict(test["initial"]["regs"])
    regs.update(test["final"]["regs"])
    return [regs[name] for name in sst386.REG_ORDER]


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    stems = sys.argv[2:] or all_stems()
    meta = sst386.load_metadata()
    revoked = sst386.load_revocations()
    waiver_doc = json.loads((pathlib.Path(__file__).resolve().parent / "sst386_waivers.json").read_text())
    waived = {w["hash"].lower(): w for w in waiver_doc["waivers"]}
    body = bytearray()
    manifest = {"source": "SingleStepTests/80386", "revision": sst386.REVISION,
                "subset": sst386.SUBSET, "files": [], "accepted": 0, "revoked": 0,
                "waived": [],
                "io_reads_not_open_bus": 0}
    accepted = 0
    for file_id, stem in enumerate(stems):
        data, provenance = sst386.load_file(stem)
        row = meta.get(sst386.base_opcode(stem))
        mask = sst386.flag_compare_mask(row)
        count = 0
        for test in sst386.parse(data):
            if test["hash"].lower() in revoked:
                manifest["revoked"] += 1
                continue
            if test["hash"].lower() in waived:
                manifest["waived"].append({"file": stem, "idx": test["idx"], "hash": test["hash"]})
                continue
            if test["initial"]["descriptors"]:
                raise ValueError(f"{stem}#{test['idx']}: descriptor state in real-mode subset")
            if any(word != 0xFFFF for word in test["io_reads"]):
                manifest["io_reads_not_open_bus"] += 1
            init = test["initial"]["regs"]
            exc = test["exception"]
            name = test["name"].encode("ascii")
            body += struct.pack("<IIIII", file_id, test["idx"], mask,
                                exc["flag_address"] if exc else NO_VALUE,
                                exc["number"] if exc else NO_VALUE)
            body += struct.pack("<I", len(name)) + name
            body += struct.pack("<20I", *[init[n] for n in sst386.REG_ORDER])
            ram = test["initial"]["ram"]
            body += struct.pack("<I", len(ram))
            for address, value in ram:
                body += struct.pack("<II", address, value)
            body += struct.pack("<20I", *final_regs(test))
            ram = test["final"]["ram"]
            body += struct.pack("<I", len(ram))
            for address, value in ram:
                body += struct.pack("<II", address, value)
            count += 1
        accepted += count
        provenance.update({"stem": stem, "id": file_id, "tests": count,
                           "flag_mask": f"0x{mask:08X}",
                           "mnemonic": row["mnemonic"] if row else None})
        manifest["files"].append(provenance)
    manifest["accepted"] = accepted
    (out / "vectors.bin").write_bytes(b"V386" + struct.pack("<I", accepted) + body)
    (out / "vector_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"prepared {accepted} tests from {len(stems)} files "
          f"({manifest['revoked']} revoked and {len(manifest['waived'])} waived tests skipped)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
