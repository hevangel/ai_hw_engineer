# 2026-11-09 - Protected-transfer review fixes

## Scope

A read-through of `src/intel_80286.sv` and the protection check units on
`main` (`0fbb7ca`) against Intel 210498-005. Branch
`design/intel-80286-review-2`. Only `src/intel_80286.sv` changed in the RTL.

## Changes

| Area | Old behavior | New behavior | Source |
|---|---|---|---|
| Far CALL to a not-present code segment | #GP(selector) | #NP(selector) after type and privilege checks | App. B CALL |
| Frame pushed from SP=0000 (same-level INT, far CALL, TSS inner stack for INT and call gate, task error-code push) | #SS(0) | Frame at FFFx-FFFF, accepted when the SS limit covers it | Assumption A44 |
| LOCK prefix, CPL>IOPL | Executed | Restartable #GP(0) at decode | App. B LOCK |
| Outer-level RETF, frame past FFFF | #GP(return CS) | #SS(0) | App. B RET |
| Unused/reserved gate and TSS descriptor fields | #GP or #TS when nonzero | Ignored | Figure 8-3 and the gate layouts: "must be 0 for 80386 compatibility"; AGENTS.md descriptor rule |

The reserved-field change covers seven sites: the direct TSS, task-gate and
call-gate descriptors of far CALL/JMP, IDT interrupt/trap/task gates, the
IDT task gate's offset word, and the TSS descriptors read for task-gate entry
and task return. The descriptor's last word is still read, so bus traces are
unchanged. Provisional assumption A26 (task-gate fields) is retired.

Post-mortem:
[review protected transfers](../../../failure_notes/2026-11-09-intel80286-review-protected-transfers.md).

## Tests

New options, all in the default bootstrap: `--call-not-present` (8 cases),
`--full-stack` (6), `--lock-iopl` (16), `--retf-overrun` (6) and
`--reserved-fields` (4). The updated testbench was also built against the
`0fbb7ca` RTL: all five fail there.

Existing fixtures changed: the direct-TSS descriptor, the direct task gate,
the current-TSS descriptor and the CPL1/CPL2 IDT task gates now carry nonzero
reserved fields. The "reserved direct TSS tail" fault row was removed (42 to
40 executions).

In `formal/intel_80286_props.sv` the IDT gate-check properties no longer
require a zero byte 4 and last word. Assertion counts are unchanged.

## Results

Image `ai-hw-engineer:latest` (Verilator 5.052, Yosys 0.69), evidence under
`work/rev2/`.

| Check | Command | Result |
|---|---|---|
| Strict lint | `verilator --lint-only -Wall --top-module intel_80286 src/*.sv` | Clean |
| Simulation | `scripts/run_sim.sh` | Exit 0, 235 `PASS:` lines (230 on `0fbb7ca`) |
| Independent vectors | `scripts/run_vectors.sh` | 99,650 Unicorn cases, 1,715,162 states |
| Physical captures | `scripts/run_hardware.sh` | Exit 0; 1,427,994 records from 316 opcode files imported and replayed |
| Historical software | `scripts/run_software.sh` | Exit 0; IBM AT BIOS workloads match Unicorn |
| Synthesis | `scripts/run_synth.sh` | Exit 0 |
| Core formal | `scripts/run_formal.sh intel_80286.sby` | BMC depth 24 PASS; k-induction (depth 12) PASS; the cover task was stopped after more than 24 hours waiting on the solver, with no result |

## Not run

- `scripts/run_all.sh` as one release run, the component formal
  configurations (their sources did not change) and the mutation campaigns.

## Open findings

- WAIT raises exception 7 whenever MSW.TS is set. Intel's MSW description
  ties WAIT's exception 7 to MP=1 and TS=1, but no primary-source quote for
  the TS=1, MP=0 case could be retrieved during this review, so the behavior
  and its `ts_wait` test are unchanged.
- A frame that only partly wraps (0<SP<frame size) and a protected IRET/RETF
  whose even-SP frame wraps past FFFF still raise #SS(0) (A44).
- The call-gate inner-stack room check does not model an expand-down target
  stack segment.
