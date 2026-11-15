# Am2616 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-78..4-82; spec.

## Properties

1. Per-driver boolean contract (all modes).
2. Inhibit dominance: HIGH inhibit forces the output to mark/LOW (all
   modes).
3. Inhibit-low data path: A is a 2-input NAND, B/C/D inverters (all
   modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

Inhibited (mark) state per driver, transmitting high/low states per
driver, mixed inhibit/transmit across drivers, and the all-inhibited
mark state.
