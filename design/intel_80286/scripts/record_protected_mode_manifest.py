#!/usr/bin/env python3
"""Record the exact inputs and tool identities for the focused replay PASS."""

import hashlib
import json
import subprocess
import sys
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def display_path(path, base):
    try:
        return str(path.relative_to(base)).replace("\\", "/")
    except ValueError:
        return str(path)


def first_line(command):
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout.splitlines()[0]


def main():
    design_dir = Path(sys.argv[1]).resolve()
    build_dir = Path(sys.argv[2]).resolve()
    result_dir = Path(sys.argv[3]).resolve()
    source_paths = sorted((design_dir / "src").glob("intel_80286*.sv"))
    source_paths.extend(
        [
            design_dir / "tb" / "protected_mode_fixture.h",
            design_dir / "tb" / "protected_mode_replay.cpp",
            design_dir / "tb" / "protected_string_replay.h",
            design_dir / "scripts" / "run_protected_mode_replay.sh",
            design_dir / "scripts" / "record_protected_mode_manifest.py",
        ]
    )

    binary = build_dir / "Vintel_80286"
    log = result_dir / "replay.log"
    if not binary.is_file() or not log.is_file():
        raise SystemExit("protected-mode binary or replay log is missing")

    manifest = {
        "schema_version": 1,
        "result": "PASS",
        "scope": "ring-0 #GP/IRET retry, reset cuts, native INS/MOVS/STOS/OUTS/CMPS fault state and repair",
        "passed_cases": sum(line.startswith("PASS:") for line in log.read_text().splitlines()),
        "ins_limit_cases": ["INSB beyond limit", "INSW straddling limit", "REP INSW last element", "INSW 64K wrap", "REP INSW nonfinal element"],
        "unverified_assumption": "A20 native port-side-effect timing",
        "string_fault_cases": ["MOVS source", "MOVS destination", "STOS", "OUTS source", "CMPS source", "CMPS destination"],
        "cmps_repeat_profiles": ["REPE equal", "REPNE unequal"],
        "string_fault_profiles": ["word REP last", "word REP nonfinal", "byte REP", "word DF=1", "word 64K wrap"],
        "wait_modes": ["unstalled", "READY stalls"],
        "reset_cuts": [
            "handler code descriptor read",
            "first protected frame byte",
            "IRET CS accessed-byte write",
        ],
        "binary": {
            "path": display_path(binary, design_dir),
            "sha256": sha256(binary),
        },
        "log": display_path(log, design_dir),
        "source_files": [
            {
                "path": str(path.relative_to(design_dir)).replace("\\", "/"),
                "sha256": sha256(path),
            }
            for path in source_paths
        ],
        "toolchain": {
            "verilator": first_line(["verilator", "--version"]),
            "compiler": first_line(["g++", "--version"]),
        },
        "build": {
            "command": [
                "MAKEFLAGS=-B",
                "verilator",
                "--cc",
                "--exe",
                "--build",
                "-j",
                "2",
                "-Wall",
                "--top-module",
                "intel_80286",
                "--Mdir",
                display_path(build_dir, design_dir),
                "-CFLAGS",
                "-std=c++17",
            ],
            "runner": "scripts/run_protected_mode_replay.sh",
            "runner_arguments": [result_dir.name],
        },
    }
    output = result_dir / "build_manifest.json"
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote source/tool manifest: {output}")


if __name__ == "__main__":
    main()
