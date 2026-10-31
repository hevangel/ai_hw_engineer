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
for the complete aggregate regression or authentic software execution.

After this checkpoint, commit e7c2520 closed the focused CMPS source slice. The
regression harness and specifications were recovered from local snapshot
f490003fb78c652eb512e5f7fdd2f97f74e0b806. At the pre-ARPL recovery checkpoint,
`run_sim.sh` recorded 103 passing checks, including the source-matched 79-case
replay, and the mutation run detected all 15 listed faults. Those CPU results
use core SHA-256
`08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca`; they do
not verify the later ARPL core. The recovered sources still need to be tracked,
and `run_all.sh`, CPGREP, full proof/cover and the native interface remain open.
See the [active audit and revised plan](../../plans/286/2026-10-26-audit-and-revised-plan.md)
for the current evidence boundary.

## Current-source refresh after ARPL — 2026-10-26

These results use the current ARPL core SHA-256
`4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634` and are
the latest checks for this source revision:

- Command: `docker run --rm --pull=never -v B:/ai_hw_engineer/worktree/intel-80286:/work -w /work ai-hw-engineer:latest bash design/intel_80286/scripts/run_protected_mode_replay.sh arpl_current_full_replay_20261026_01`
- Result: exit 0, 79 PASS cases, strict Verilator 5.052 build. The manifest and executable are under `design/intel_80286/work/arpl_current_full_replay_20261026_01/`; the binary SHA-256 is `2141eb75429e89244c0cc3af931b814e1337077749a273f1d21b4aee05f474d8`.
- Scope: protected event #GP/IRET recovery and reset cuts, plus INS/MOVS/STOS/OUTS/CMPS fault-repair profiles, in both READY modes.
- The mutation command consumed that replay's manifest with `run_protected_string_mutations.py` and exited 0; all 15 mutants were detected with expected diagnostics. Evidence is under `design/intel_80286/work/arpl_current_full_mutations_20261026_01/`.
- Yosys 0.69 completed `hierarchy -check`, `synth`, and `check -assert` on the full core hierarchy with zero reported problems and 29,964 cells. Script and log are under `design/intel_80286/work/arpl_current_checks_20261026_01/`; output JSON is `intel_80286.json`.
- The connected-core `intel_80286.sby` run uses `FORMAL_WORK_DIR=/work/design/intel_80286/work/arpl_current_formal_20261026_01`. Depth-24 ABC BMC passes with SBY status `PASS 0 1577` (26m17s), with no counterexample. Depth-12 prove is `UNKNOWN`: the base case passes through 12, but induction fails at `intel_80286_props.sv:154`. The induction state has code-load target 2 with request `1E80:FFFC` while the saved IRET target is `0200:00F3`; the property antecedent does not require the RTL branch's selector/offset match and zero special-descriptor result. This is an induction/property-strengthening issue, not a reachable counterexample. The depth-64 cover search was interrupted after 28 witnesses at step 20 and has no terminal status. The repository exact-source auditor reports 37/40 tasks PASS: all 36 components and current BMC pass; prove is UNKNOWN, cover is incomplete, and preserved PDR evidence is stale for current RTL. Its output is `design/intel_80286/work/arpl_current_formal_20261026_01/audit.json`.

The refreshed replay, mutations and synthesis do not qualify full 80286
behavior, independent pin timing or the release aggregate. Track final formal
task statuses and source/config hashes in the active [audit and revised plan](../../plans/286/2026-10-26-audit-and-revised-plan.md).
