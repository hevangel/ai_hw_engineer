# MOS 8520 CIA implementation plan (in progress)

The 8520 is the Amiga's CIA. MAME's `mos6526.cpp` (revision
`41a494b6ef80adc924ccb2bdba1ee69580276e0c`; SHA-256
`7fded393c9fbcdcf3224085d7fce20fc6acc292dc795b00fb5fb312b8f27602f`, header
`d2cde5ea197596fe17afe82c27f29e1994091479403a4a4db7d7702fca21f83c`) models
it as a 6526 variant and cites vAmigaTS hardware tests. Its 8520 deltas:

- 24-bit binary TOD event counter with a nibble-ripple carry seen half way
  by the alarm comparator; hours register reads $FF and ignores writes;
  the minutes read latches unless CRB alarm is selected; a minutes write
  stops the counter unless the alarm is selected.
- A timer-high write force-loads and starts a one-shot timer.
- Interrupt sources are latched one cycle after they form.
- CRA bit 7 (TOD frequency) does not exist (`cra_mask` $6F).

## Plan

1. Classify agreement between the qualified `design/mos_6526` RTL (VICE,
   transistor netlist, Lorenz and other original software) and MAME's
   6526 core before using MAME for 8520 deltas. First exploratory run
   (2026-10-23, `tb/cia6526_compare.cpp`, board pull-ups resolved in the
   harness): 333,660 random reads over 2,000,000 cycles, 235 timer-count
   mismatches, all in timer counter reads after random control writes.
   Each mismatch class must be traced to its trigger and resolved against
   the existing independent evidence; MAME is not assumed correct.
   First class traced: a timer-high write to a *stopped* timer followed by
   a counter read on the next cycle. The RTL (agreeing with VICE's unchanged
   timer code over 3.6 million cycles) already returns the reloaded
   counter; MAME returns the previous counter for one more cycle. This is a
   VICE/MAME disagreement on reload latency, open until physical evidence
   (e.g. the merlintwa measurements) or original software decides it.
   The second traced mismatch is the same class (a low-latch write one
   cycle after the stopped-timer high write is captured by MAME's later
   load). With accesses to a timer suppressed for three cycles after its
   high-byte write (`AVOID_RELOAD=1`), 26 mismatches remain in 2,000,000
   cycles; the first divergence is on the IRQ line at cycle 110,062,
   without an adjacent register access (an ICR read 16 cycles earlier);
   the underflow-to-IRQ path, possibly seeded by the reload-latency
   difference, is the next trace.
   Traced: timers and ICR flags agree cycle for cycle there; the RTL
   asserts /IRQ one cycle after the ICR flag, MAME's 6526 two cycles after.
   Counting every cycle (fixed harness), the RTL differs on /IRQ in 125 of
   2,000,000 cycles from MAME's 6526 and in 113 from MAME's 6526A, with six
   further read mismatches outside the reload class; the RTL's
   `TIMER_B_READ_LOSS` setting does not change these totals. The RTL's IRQ
   path was qualified against VICE and original Lorenz software; MAME's
   was reworked against its own hardware tests. Resolving which is right
   requires physical captures, so the 8520 is built on the qualified 6526
   core and the MAME comparison reports residuals against these classes.
2. Implement `mos_8520` reusing the 6526 timer/serial/IRQ blocks with an
   8520 TOD block and the deltas above; compare with MAME's 8520 under the
   classification from step 1.
3. Formal invariants and covers, replay in both simulators, synthesis.
4. Kickstart/Amiga software qualification belongs to the Amiga chip set
   work; it is not required by the four requested systems.
