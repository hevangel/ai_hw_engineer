# PIT Mode 0 rewrite failed to re-arm OUT

## External observation

Unchanged IBM PS/2 Model 30 revision 2 BIOS (February 5, 1987) stopped with
`102-System Board Error`. At F000:0663 it programmed PIT channel 0 in
LSB-only Mode 0, loaded 2Ch and received IRQ0. At F000:0688 it rewrote the
count to FFh without a new control word. No second IRQ0 arrived, so POST
exhausted its polling loop and halted at F000:0684 (post-HLT IP 0685).

## Root cause

The timer RTL lowered OUT only when programming the Mode 0 control word.
Count writes stopped/reloaded the counter but retained terminal OUT high.
Existing tests reprogrammed the control word before each scenario, hiding
the missing low-to-high edge. Formal checked control-word effects and
counting invariants, but had no count-rewrite output obligation.

## Authority and fix

Intel's [8254 datasheet](https://www.scs.stanford.edu/10wi-cs140/pintos/specs/8254.pdf),
Mode 0 definition on printed p.10, requires a new count to re-arm OUT low.
For a two-byte count, the first write lowers OUT immediately, without a
counter clock. The next counter clock loads the completed count; only
subsequent clocks decrement it. Both variants share this mode behavior.
The RTL now lowers OUT for each complete single-byte Mode 0 count write
and the first byte of a two-byte rewrite.

The dual-variant test first reaches terminal OUT high, rewrites a count
without touching the control word, checks immediate OUT low with no CLK,
checks partial two-byte writes stay stopped, and checks the exact second
terminal edge. LSB-only, MSB-only and LSB/MSB formats are covered. A separate
formal assertion checks single-byte writes' manufacturer-defined OUT effect.

## Verification and prevention

Run `design/intel_8253_8254/scripts/run_all.sh` for strict lint, dual-variant
simulation, BMC/PDR/non-vacuity covers and synthesis. The Model 30 aggregate
flow must also run unchanged POST, preserving this real-software oracle.
Actual results are recorded in the chip and system reports.

Mode tests must include reprogramming an already-completed device through
each documented write format, not only reset/control-word initialization.
