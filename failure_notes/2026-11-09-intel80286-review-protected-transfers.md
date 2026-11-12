# 80286 protected transfers: five rules found by review — 2026-11-09

## What broke and how it was found

A read-through of `design/intel_80286/src/intel_80286.sv` against Intel
210498-005 found five protected-mode defects. The design's own suite passed
with all of them present (baseline `run_sim.sh` exit 0 on `0fbb7ca`). Each
was then reproduced with a new directed test that fails on that source.

| Defect | Old behavior | Correct behavior |
|---|---|---|
| Far CALL to a not-present code segment | #GP(selector) | #NP(selector), after the type and privilege checks (App. B CALL) |
| Frame pushed from SP=0000 on a 64K stack (same-level INT, far CALL, TSS inner stack, task error-code push) | #SS(0), escalating to #DF and shutdown | The frame lies at FFFx-FFFF and fits (assumption A44) |
| LOCK prefix with CPL>IOPL | Executed | #GP(0) (App. B LOCK) |
| Outer-level RETF whose frame runs past FFFF | #GP(return CS) | #SS(0), as for the outer-level IRET (App. B RET) |
| Nonzero unused/reserved gate and TSS descriptor fields | #GP or #TS | Ignored; zero is an 80386 compatibility rule |

## Root cause and why verification missed it

- **CALL not present.** `CALL_DESC_CHECK` had a shortcut that raised #GP for
  any code/data descriptor with P=0 before the code loader ran. The far JMP
  path had no such shortcut and was correct. Tests covered not-present call
  *gates* and gate targets, never a direct CALL to a not-present segment.
- **SP=0000.** Five sites compared `SP < frame size` before pushing. Every
  protected fixture uses a stack with limit 00FFh and SP=0080h, so no test
  started from an empty full-size stack, the common `SS:0000` setup.
- **LOCK.** The gap was listed as open in `plans/isa_inventory.md` and had
  no test.
- **RETF overrun.** The branch dated from the first scoped CPU commit and
  copied the neighbouring null-CS fault. The IRET twin was corrected later;
  the RETF one had no test.
- **Reserved fields.** The 2026-10-28 task-gate note already removed one such
  rule and added the AGENTS.md "286 descriptor contracts" rule. Six other
  sites kept the same pattern, one as provisional assumption A26, and one
  fault-matrix row asserted it. Fixtures always wrote zeros, so the checks
  were never exercised except by that row.

The common cause is fixture uniformity: one stack shape, zero-filled reserved
fields and gate-only presence cases let these paths stay unexercised. Two of
the formal properties mirrored the RTL's reserved-field conditions, so the
proof agreed with the defect.

## Fix and re-verification

The RTL changes are in `intel_80286.sv` only. New tests:
`--call-not-present`, `--full-stack`, `--lock-iopl`, `--retf-overrun` and
`--reserved-fields`; all five fail on `0fbb7ca` and pass on the fix. The
direct-TSS, task-gate and IDT task-gate success fixtures now carry nonzero
reserved fields, and the fault-matrix row that asserted #TS for a reserved
TSS word was removed. Results are in
`design/intel_80286/report/2026-11-09-review-fixes.md`.

## Prevention

- Protected-mode stack tests must include a full-size stack (limit FFFFh)
  starting at SP=0000, not only the small fixture stack.
- A presence, type or privilege rule tested for a gate must also be tested
  for the direct (non-gate) form of the same transfer.
- Success fixtures write nonzero values into every field Intel marks unused
  or reserved, per the existing AGENTS.md descriptor rule.
- A property that restates an RTL condition is not independent evidence;
  cite the Intel table row beside it.
