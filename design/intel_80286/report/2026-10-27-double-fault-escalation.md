# Protected double-fault escalation checkpoint

**Date:** 2026-10-27 10:59 UTC  
**Scope:** #GP while fetching the handler gate for an initial #GP  
**Issue:** [hevangel/ai_hw_engineer#80 checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440006292)

## Architectural rule and change

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
requires vector 8 when a second fault occurs during one instruction and the
first fault was vector 0, 10, 11, 12 or 13. The double-fault error code is
null and the saved address identifies the original instruction. The manual
also requires a task gate for the double-fault handler so the handler receives
a proper task state.

The protected `EVENT_START` path now recognizes one concrete nested-fault
case: an IDT-limit #GP while attempting to invoke an initial restartable
#DE/#TS/#NP/#SS/#GP handler. It converts the event packet to vector 8, sets an
error-code slot containing zero, preserves the original saved CS:IP:FLAGS:SP,
and retries vector lookup at #DF. Other nested-fault sites and full task-gate
dispatch remain open.

## Evidence

The test-first regression failed against the previous RTL because it retained
the first #GP packet instead of producing vector 8. After the RTL change,
`--iopl-controls` passes the two nested #GP cases in immediate and stalled
READY modes. The fixture executes HLT at CPL3 to raise the first #GP, then
uses an IDT limit that makes fetching vector 13's gate raise another #GP while
still allowing the vector-8 gate lookup. It checks vector 8, null error code,
restartability, exact original saved state, no retirement, and that the only
IDT reads are the eight bytes of the vector-8 gate.

The fixture leaves the vector-8 descriptor all-zero. The current
interrupt/trap-only gate validator rejects it and reports a diagnostic stop.
This checkpoint verifies the #DF packet and vector lookup only; it does not
execute task-gate semantics, enter a #DF handler, or test shutdown behavior.

The full default bootstrap and release preflight pass. Evidence is under
`work/double_fault_classification_20261027_01/`:

- `test_first.log` — expected failure before the RTL change.
- `iopl_controls.log` — focused pass after the change.
- `full_bootstrap.log` — complete default bootstrap.
- `build_manifest.json` — Verilator 5.052 `-Wall` exact-source manifest.

| Artifact | SHA-256 / count |
|---|---|
| RTL `src/intel_80286.sv` | `2777eaea08bd5de2247a994d1468ab707f5d596d4e367915bb097c031af75d90` |
| Testbench `tb/bootstrap.cpp` | `42a1726bd7dd589426934650f947788944b732c23c763f2540a222362eb8d137` |
| Formal properties | 299 assertions, 1 assumption, 50 covers; SHA-256 `d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb` |
| Built runner | `15955606505bb88e5e3e3db982f47c6b4c550eb9168a18cfeafc5697ef326a07` |
| Build fingerprint | `50306e079cfaa8a48e8dd565ca9e092620e7aef3dbb5015f7d42333dc9f599d8` |

## Remaining work

The connected-core property source now asserts that this specific IDT-limit
transition selects vector 8, sets the null error code, preserves the saved
CS:IP:FLAGS:SP:SS, and does not retire or enter normal gate delivery. A cover
marks the transition reachable. Preflight accepts the reviewed inventory at
299 assertions, one assumption and 50 covers. The live `_21` formal jobs use
older snapshots, so this new property has not yet been proved or covered. At
10:58:49 UTC PDR was at frame 29 with 366 outputs proved and 28 timeouts; the
cover job remained at step 35, last logged waiting at 10:42:24 UTC.

Implement the IDT task-gate entry and 286 nested task switch, including the
incoming busy bit, outgoing dynamic TSS save, backlink, NT, incoming TSS
loads, segment validation and error-code placement. Add task IRET through the
backlink, the remaining double-fault cause matrix, and 286 shutdown behavior
when a protection violation occurs while processing vector 8. These remain
completion gates; this report records only the first #DF-vector selection
transition.

The older connected-core cover/PDR jobs remain live on prior RTL/property
snapshots. There is no connected-core formal result for this RTL update.
