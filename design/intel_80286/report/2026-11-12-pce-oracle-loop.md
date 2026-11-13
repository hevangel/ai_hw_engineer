# 2026-11-12 - PCE-286 oracle loop

## Scope

First use of the PCE-286 comparison (`plans/pce_oracle_loop.md`) on branch
`design/intel-80286-review-2`. PCE-286 is pinned at `adf2ef3`
(`external/pce-286`); 86Box at `757b67f` was read as a second opinion.
Three sub-agents (two Opus, one Sonnet) each owned a group of scenario
families, classified every mismatch and fixed or waived it.

## Result

| Run | Scenarios | Pass | Mismatch | Waived |
|---|---|---|---|---|
| First run (after normalizing FLAGS bit 1 in the oracle driver) | 2,936 | 2,647 | 289 | 0 |
| After the loop | 2,992 | 2,891 | 0 | 101 |

All ten scenarios for the 2026-11-09 review fixes agreed with the oracle
from the first run.

## RTL changes

| Area | Old behavior | New behavior | Basis |
|---|---|---|---|
| Fault taken in an incoming task | Same-level handler entered with the outgoing task's SP minus the frame | Incoming SP minus the frame | 210498-005 section 8.3 (as quoted in this repo); both emulators |
| CALL/JMP through a task gate to a non-TSS target | #TS(selector) | #GP(selector); only a short available TSS is #TS | Table 8-1 and the IDT task-gate path's App. B citation; both emulators |
| Protected PUSHA near the stack limit | Wrote the words that fit, then faulted; wrapped for small even SP | Whole 16-byte frame checked first; 0<SP<16 is #SS(0) | Restartability; A44. 86Box wraps instead |
| LAR on interrupt and trap gates | Accepted (types 1-7) | Rejected (types 1-5) | A45: both emulators; no Intel text retrieved |
| WAIT with TS=1, MP=0 | Exception 7 | Executes | A46: PCE-286; no primary-source quote retrieved |

The handler-SP change also corrects a #DF promoted from an event without
an error code, whose handler SP was two bytes off. That case was found by
reading and has no test.

## Waivers (101 scenarios, 13 patterns)

| Pattern | Scenarios | RTL | PCE-286 | Why the RTL is kept |
|---|---|---|---|---|
| ARPL with a null source selector | 48 | #GP(0) | Executes | Intel B-2/B-3 stepping information sheet cited in the ARPL report; neither emulator models it |
| Incoming task with an invalid SS or LDT | 20 | Shutdown | Fault delivered on the outgoing task's stale SS cache | AGENTS.md task-fault-context rule; vector and error code agree when routed through task gates (50 added scenarios) |
| Outer IRET with an invalid return SS | 12 | #SS(selector) | #GP(selector) | A31 (Table 7-4) against App. B; open source conflict |
| INT through a task gate to a busy, null or local TSS selector | 6 | #GP | #TS | Table 8-1 and App. B B-49; 86Box uses #GP for the 286 |
| Accessed bit set before a later fault | 6 | Set | Not set | A13/A19 order; Intel does not define it |
| ESC port cycles | 4 | Issued | None | The oracle has no 80287 attached |
| JMP to a task whose TSS image has NT=1 | 2 | NT cleared | NT kept | Table 8-2 reading in the NT failure note; unresolved |
| Inner-stack room fault error code | 2 | #SS(0) | #SS(selector) | App. B B-49; 86Box agrees with the RTL |
| LGDT register operand at CPL 3 | 1 | #UD | #GP | Priority not stated; 86Box agrees with the RTL |

## Open questions

- Outer RETF raises #GP for an invalid return SS while outer IRET raises #SS
  under A31, which claims to cover both.
- A CALL/JMP task gate whose TSS selector is beyond the GDT limit raises
  #TS; the IDT path raises #GP for the same case. No scenario covers it.
- The call-gate inner-stack room fault pushes #SS(0); Intel may specify the
  SS selector there.
- A45, A46, the NT-on-JMP rule and the ARPL rule rest on emulators or
  second-hand citations. None was checked against the manual pages in this
  session.

## Verification

Image `ai-hw-engineer:latest`, evidence under `work/final/`, on the merged
tree.

| Check | Result |
|---|---|
| Strict lint | Clean |
| `scripts/run_pce_oracle.sh` | 2,891 pass, 0 mismatch, 101 waived |
| `scripts/run_sim.sh` | Exit 0, 235 `PASS:` lines |
| `scripts/run_hardware.sh` | Exit 0 |
| `scripts/run_software.sh` | Exit 0 |
| Core k-induction (`intel_80286.sby prove`, depth 12) | PASS after two property updates |

The two property updates: the handler-SP assertion restated the old RTL
assignment (the defect itself) and now states the frame-size rule; the
precheck-only invariant gained a case for the PUSHA frame check (437 to 440
assertions).

Not run on the merged tree: core BMC to depth 24, the cover task, the
component formal configurations, synthesis, the mutation campaigns and
`run_all.sh`.
