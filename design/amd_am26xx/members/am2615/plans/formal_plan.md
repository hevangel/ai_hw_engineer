# Am2615 formal plan

Reference: AMD 1974 Data Book pages 4-51..4-56; spec.

## Properties

1. Per-receiver OUT = !(COMP && STROBE), formulated independently of
   the RTL (all modes).
2. Strobe-idle: strobe LOW holds the output HIGH (all modes).
3. Fail-safe: equal-input (open-line) ties resolve to COMP = 1, so the
   output is the strobe inversion (all modes).
4. Defined differential states: (1,0) passes the strobe inversion;
   (0,1) forces the output HIGH (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

Both differential states per receiver with strobe active,
strobe-disabled outputs, tie states (fail-safe) strobed and idle, and
the two receivers strobed independently.
