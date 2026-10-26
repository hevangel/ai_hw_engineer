# Protected CMPS fault repair checkpoint

Updated 2026-10-26 in the `design/intel-80286` worktree. This report records a
focused implementation result; it does not close the full 80286 verification
or completion requirements.

## Behavior and sources

Intel order 210498-005 defines CMPS comparison flags from the source operand
at DS:SI (or a source override) minus the destination at ES:DI. The original
[80286/80287 Programmer's Reference Manual](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
is the source for that arithmetic order. The [Intel LOADALL memo, page
14](https://docs.pcjs.org/manuals/intel/80286/80286_LOADALL.pdf) supplies the
handler-repair rules used here:

| Faulting reference | Native post-fault indices | Native repeated count | Handler repair before retry |
| --- | --- | --- | --- |
| First reference, ES:DI | DI advances by the signed operand width; SI is unchanged | CX decreases by 1 | Restore DI; add 1 to CX |
| Second reference, DS:SI, after ES:DI succeeded | DI and SI both advance by the signed operand width | CX decreases by 2 | Restore DI and SI; add 2 to CX |

An unprefixed instruction leaves CX alone. The tests cover DF in both
directions, byte/word width, 64K word wrap, final/nonfinal REP, equal REPE and
unequal REPNE profiles, fault-frame flags, exact retry PC/successor, operand
traffic and READY stalls. The functional model checks ES:DI before DS:SI.
That ordering remains assumption A6 for the model; no independent native
per-beat trace establishes physical bus ordering.

## RTL and regression result

The core applies phase-specific SI/DI/CX repair in MEMORY_CHECK and permits
protected CMPS word references at offset FFFF to reach segment checking, so
the fault phase remains visible for repair. CPU properties check the expected
register changes and exempt only recognized protected native string fault
cycles from the otherwise stable-register property. The replay checks
source-minus-destination flags against independent fixture values.

Final replay evidence is under
`design/intel_80286/work/protected_cmps_native_20261025_03/`:

- Command: `docker run --rm --pull=never -v B:/ai_hw_engineer/worktree/intel-80286:/work -w /work ai-hw-engineer:latest bash design/intel_80286/scripts/run_protected_mode_replay.sh protected_cmps_native_20261025_03`
- Result: exit 0, 79 PASS lines, strict Verilator 5.052 (`-Wall`) build.
- Manifest: `build_manifest.json`, result PASS, 19/19 named source inputs still match the worktree.
- Core SHA-256: `08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca`.
- Replay binary SHA-256: `6713a06c6b36c1f2585565748912081e222a143e0e899a297bc02163160a89fd`.

Mutation evidence is under
`design/intel_80286/work/protected_cmps_mutations_20261025_03/`:

- Command: `docker run --rm --pull=never -v B:/ai_hw_engineer/worktree/intel-80286:/work -w /work ai-hw-engineer:latest python3 design/intel_80286/scripts/run_protected_string_mutations.py design/intel_80286/work/protected_cmps_native_20261025_03/build_manifest.json protected_cmps_mutations_20261025_03`
- Result: exit 0; all 15 mutations compiled and failed with their expected semantic diagnostic. Five mutations target CMPS repair/wrap/compare behavior.
- The mutation manifest retains each mutant core hash and build-log hash.

Structural checks are under
`design/intel_80286/work/cmps_checks_20261026_01/`:

- Synthesis command: `docker run --rm --pull=never -v B:/ai_hw_engineer/worktree/intel-80286:/work -w /work ai-hw-engineer:latest yosys -Q -q -l design/intel_80286/work/cmps_checks_20261026_01/synthesis.log -s design/intel_80286/work/cmps_checks_20261026_01/synth.ys`
- Yosys 0.69 completed the full hierarchy and all three `check` passes reported zero problems.
- The `checks.sby` depth-12 BMC task is PASS (`bmc12_02/status`: `PASS 0 185`). Its 21 RTL/property snapshot files match the current source. This is a shallow smoke bound and does not reach the complete protected fault/handler workload.
- The depth-64 cover task timed out at its configured 180-second limit (`cover64_01/status`: `TIMEOUT 8 90`). It produced 11 complete witnesses; 53 cover statements remained unreached. The SBY task configuration and logs are preserved, but the outer Docker command line was not recorded in the output directory.
- The current CPU property source SHA-256 is `430fc631524a30ea1637cab2e8d021c9204aee3bd6aea80b605eb7a6aaac83d2`; all 21 formal source files in both BMC and cover snapshots match the worktree.

Earlier failed CMPS fixture/mutation attempts and the initial BMC parse error
remain in their separately named ignored work directories. The final result
above refers only to the passing replay and mutation directories named here.

## Limits and follow-up

This result does not establish native bus-beat order or A20 port timing, resolve
the SCAS SI/DI discrepancy in the old memo, test INS DF=1 integration or I/O
privilege faults, run OS/2 SDK CPGREP, or complete any broad ISA, LDT/TR,
privilege/task, event-delivery, native-interface, full proof/cover or release
gate. In particular, this source-controlled focused replay is not a substitute
for the missing broad regression sources or authentic software execution.

The next work is to review and commit this focused slice with its report, then
restore the missing source-backed regression baseline and establish an
independent 286 software/trace path. The active, full-chip sequence is in
[`plans/286/2026-10-26-audit-and-revised-plan.md`](../../plans/286/2026-10-26-audit-and-revised-plan.md).
