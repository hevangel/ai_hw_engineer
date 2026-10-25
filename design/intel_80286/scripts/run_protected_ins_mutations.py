#!/usr/bin/env python3
"""Require the integrated INS replay to reject specific RTL faults.

Run after run_protected_mode_replay.sh. All mutations operate on fresh copies
under work/; the baseline manifest must match the current source exactly.
"""

import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit("Usage: run_protected_ins_mutations.py BASELINE_MANIFEST [NEW_RUN_NAME]")
    design = Path(__file__).resolve().parent.parent
    baseline_path = Path(sys.argv[1]).resolve()
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    if baseline.get("result") != "PASS" or len(baseline.get("ins_limit_cases", [])) != 5:
        raise SystemExit("Baseline must be a passing replay including all five INS cases")
    for source in baseline["source_files"]:
        path = (design / source["path"]).resolve()
        if not path.is_relative_to(design) or sha256(path) != source["sha256"]:
            raise SystemExit(f"Stale or invalid baseline source: {source['path']}")

    name = sys.argv[2] if len(sys.argv) == 3 else (
        "protected_ins_mutations_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
        raise SystemExit("Run name must contain only letters, digits, underscores and hyphens")
    work = design / "work"
    if work.resolve() != work:
        raise SystemExit("Refusing an aliased work directory")
    result = work / name
    result.mkdir(exist_ok=False)
    original = (design / "src/intel_80286.sv").read_text(encoding="utf-8")
    mutations = [
        (
            "ignore_destination_denial",
            "MEMORY_CHECK: begin\n                    if (data_reference_allow) begin",
            "MEMORY_CHECK: begin\n                    if (data_reference_allow || ins_precheck_active) begin",
            "denied INS consumed input before ES repair (A20)",
        ),
        (
            "check_only_first_byte",
            "memory_start(1'b1,0,gpr[7],24'd0,1'b1,1'b0,\n"
            "                                     wide ? 3'd2 : 3'd1,0,STRING_FIRST);",
            "memory_start(1'b1,0,gpr[7],24'd0,1'b1,1'b0,\n"
            "                                     3'd1,0,STRING_FIRST);",
            "denied INS consumed input before ES repair (A20)",
        ),
        (
            "save_successor_pc",
            "enter_event(data_reference_vector,instruction_ip,1'b0,1'b1,1'b1,data_reference_error);",
            "enter_event(data_reference_vector,ins_precheck_active ? ip : instruction_ip,"
            "1'b0,1'b1,1'b1,data_reference_error);",
            "INS fault packet or completed-element state is imprecise",
        ),
        (
            "keep_pre_fault_indices",
            "if (msw[0] && ins_precheck_active) begin",
            "if (1'b0 && msw[0] && ins_precheck_active) begin",
            "INS fault packet or completed-element state is imprecise",
        ),
        (
            "decrement_rep_twice",
            "if (repeat_valid) gpr[1]<=gpr[1]-16'd1;",
            "if (repeat_valid) gpr[1]<=gpr[1]-16'd2;",
            "INS fixture retired PC or exact successor mismatch",
        ),
    ]
    record = {
        "baseline_manifest": str(baseline_path.relative_to(design)),
        "baseline_manifest_sha256": sha256(baseline_path),
        "runner_sha256": sha256(Path(__file__)),
        "source_files": baseline["source_files"],
        "mutations": [],
    }
    for label, old, new, diagnostic in mutations:
        if original.count(old) != 1:
            raise SystemExit(f"Mutation {label} must match exactly one source location")
        snapshot = result / label
        snapshot.mkdir()
        for directory in ("src", "tb", "scripts"):
            shutil.copytree(design / directory, snapshot / directory,
                            ignore=shutil.ignore_patterns("__pycache__"))
        core = snapshot / "src/intel_80286.sv"
        core.write_text(original.replace(old, new), encoding="utf-8")
        command = ["bash", str(snapshot / "scripts/run_protected_mode_replay.sh"), "replay"]
        print(f"Building mutation: {label}", flush=True)
        with (snapshot / "build.log").open("w", encoding="utf-8") as log:
            process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        output = (snapshot / "build.log").read_text(encoding="utf-8")
        # Compilation/tool errors do not count as detecting a semantic fault.
        caught = process.returncode != 0 and f"FAIL: {diagnostic}" in output
        replay_log = snapshot / "work/replay/replay.log"
        caught = caught and replay_log.is_file() and "PASS: protected #GP" in output
        record["mutations"].append({
            "name": label, "detected": caught, "exit_code": process.returncode,
            "expected_diagnostic": diagnostic, "core_sha256": sha256(core),
            "log": str((snapshot / "build.log").relative_to(design)),
            "log_sha256": sha256(snapshot / "build.log"),
        })
        (result / "mutations.json").write_text(json.dumps(record, indent=2) + "\n")
        if not caught:
            raise SystemExit(f"Mutation {label} was not rejected as expected; inspect {snapshot / 'build.log'}")
        print(f"PASS: detected {label}: {diagnostic}", flush=True)
    print(f"PASS: all {len(mutations)} INS mutations detected; evidence: {result}", flush=True)


if __name__ == "__main__":
    main()
