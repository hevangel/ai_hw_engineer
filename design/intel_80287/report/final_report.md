# Verification report: Intel 80287, milestone M1 (architectural model)

Date: 2026-11-27. Canonical issue: [hevangel/ai_engineer#113](https://github.com/hevangel/ai_engineer/issues/113).

## Summary

| Gate | Result |
| --- | --- |
| Lint (Verilator 5.052 `-Wall`, `VARIANT=1`) | pass |
| Shared x87 suite with the 80287's differences, plus 80287-only tests | **246,934 checks pass** (340,167 cycles) |
| Host-x87 finite arithmetic (7,680 cases), 180 square roots, rounding ties | pass (part of the suite) |
| Original Intel ARRSUM software | pass |
| Controller formal (`VARIANT=1`) | FORMAL_RESULT |
| Synthesis elaboration | SYNTH_RESULT |

This is an **architectural** 80287 behind the transaction interface. The native processor-extension I/O interface to the 80286 is milestone M2. Not acceptance of issue #113.

## What was verified

The 80287 differences listed in Intel 210498-005 Appendix B and chapter 2 are each checked by a directed test (`tb/tb_80287_extra.hpp`, plus the variant branches of the shared suite):

- ERROR# is asserted whatever IEM says;
- FENI and FDISI change no state;
- FSETPM selects protected-mode pointer images (IP offset, CS selector, operand offset, operand selector, no opcode); FINIT keeps that mode, and only RESET leaves it;
- FSTSW AX returns the status word without updating the pointers;
- real-mode images keep the 8087 layout;
- FLDENV/FSTENV and FSAVE/FRSTOR work in protected format;
- initialization gives 03FFh.

Everything else is the shared 8087 suite run unchanged on the `VARIANT = 1` build. That covers:
- host-x87 arithmetic across all PC/RC settings;
- all memory formats;
- memory stalls and reset during a store;
- traps and their retirement rules;
- projective infinity;
- the Intel ARRSUM program.

## Limits

- **P-A1:** the 80287's numerics are taken to be the 8087's, on the strength of Intel's statement that the differences are system-level. There is no 80287-specific numeric capture yet.
- **P-A3:** the conflicting FSTENV text in the 1987 manual is resolved in favour of the 8087 behaviour. This is unvalidated.
- **Not covered:** native pins, PEREQ/PEACK# operand transfers, BUSY#/ERROR# timing and instruction timing.
