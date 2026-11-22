# 80286 protected-mode fault rules and CPL found by review — 2026-11-22

## What broke and how it was found

An external review of `design/intel_80286` at `dfdc0db` (issue #284, revised
2026-11-20) compared protected-mode control transfers and task switching with
Intel 210498-005 Appendix B and reproduced each defect with a directed
LOADALL harness. The design's own suite, its formal properties and the
PCE-286 oracle loop all passed with every one of them present. The harness
was rerun on `main` (all reproduce) and on the fix (all match Intel).

| Finding | Old behaviour | Intel 210498-005 |
|---|---|---|
| 1, HIGH | #DF through an interrupt or trap gate at vector 8 shut the CPU down | Any interrupt, trap or task gate is valid (App. B INT, p. B-49) |
| 2 | Outgoing TSS needed limit 43; the switch wrote LDTR into TSS+42 | Current TSS limit >= 41; words 0-13 are saved, the LDT word is only read (SWITCH_TASKS, p. B-12) |
| 3 | CALL/JMP task gate with a local or out-of-range TSS selector: #TS | #GP(TSS selector) (pp. B-25, B-57) |
| 4 | IRET whose back link names an available TSS: #GP | #TS(new TSS), before the presence check (p. B-51) |
| 5 | Call-gate stack switch rejected an expand-down inner or caller stack with #SS(0) | Expand-down stacks are valid stacks |
| 6 | Outer-level IRET and RETF reported a bad return SS differently (#SS versus #GP) | The same list for both: #GP(selector), #SS only for not present (pp. B-52, B-95) |
| 7 | Target IP limit tested before the stack checks on CALL and interrupts | Stack room and inner-stack checks first, then the IP limit (pp. B-24, B-25, B-49) |
| 14, HIGH | CPL was the low two bits of CS, so after LMSW a loader at a real-mode segment such as 1233h ran at "CPL 3" and its LLDT, LTR and far JMP to DPL-0 code faulted | Setting PE leaves the processor at level 0 until the first protected CS load (section 10.4.2, p. 10-7) |

## Root cause and why verification missed it

- **Programmer advice read as a processor check (1).** Section 9.6.2 tells
  the system programmer to use a task gate for #DF. The RTL turned that into
  a gate-type fault, the connected-core property asserted the same rule, the
  spec and a review report stated it as processor behaviour, and the PCE
  scenarios routed #DF only through task gates. Spec, RTL, property and
  oracle scenarios shared one reading, so nothing disagreed.
- **Fixture shape (2, 5, 14).** Every TSS fixture had limit 43 and a zero LDT
  word, every stack fixture was expand-up, and every entry to protected mode,
  in the tests, the PCE scenarios and the IBM AT BIOS, ran from segment
  F000h, whose low two bits are 00. The paths that differ were never driven.
- **Shared misreadings in tests and documents (3, 4).** The directed test for
  finding 4 expected #GP and the privilege-transition spec documented it;
  finding 3 was an open question in the oracle report that had not been
  checked against the manual.
- **A waiver that absorbed a real disagreement (6).** The manual is
  internally inconsistent (Table 7-4 versus Appendix B). Assumption A31 chose
  Table 7-4 for IRET only, and 12 oracle waivers accepted the resulting
  PCE-286 mismatches instead of resolving the inconsistency for both
  instructions.
- **Ordering hooks tied off (7).** The CS checker had `call_i`/`stack_ok_i`
  inputs that would have ordered #SS first, but the core tied them off, and
  no test had the stack fault and the IP fault present together.

## Fix and re-verification

One commit per finding on `design/intel-80286-fable-review-284`
(findings 1-9 started by the issue's previous owner and re-verified here).
Directed tests: the bootstrap fault matrices extended for findings 1-9,
`--pe-entry` for finding 14 (fails on `main`, segment ending 01), and the
review harness `T1`-`T9`, whose output on `main` and on the fix is recorded
in `design/intel_80286/report/final_report.md`. The PCE oracle no longer
needs the A31 waivers, and a new `near_limit` scenario family settles
finding 10. The full release gate, now including the PCE oracle, is in the
same report.

## Prevention

- AGENTS.md now has a "286 manual advice versus processor checks" rule:
  "should" and "must use" advice to the system programmer is not a fault
  condition unless Appendix B lists it.
- Protected-mode fixtures vary the shapes the review found unexercised:
  minimum TSS limits (41 outgoing, 43 incoming) with a nonzero LDT word,
  expand-down inner and caller stacks, and protected-mode entry from
  real-mode segments with every low-bit pattern.
- A fault-ordering rule needs a test with both faults present.
- An oracle waiver must cite the primary-source page it rests on, and a
  waiver group is re-opened whenever the manual is checked for its topic.
