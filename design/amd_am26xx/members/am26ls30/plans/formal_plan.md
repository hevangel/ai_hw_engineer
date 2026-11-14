# Am26LS30 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-30..4-35; spec.

## Properties

1. RS-423 mode: all four outputs equal their inputs (all modes, `===`
   exactness).
2. RS-422 mode: enabled pairs drive complementary values; disabled
   pairs are exactly `z` (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

Every row of the published function table for both pairs, the RS-423
data combinations, and slew-pin independence in both modes.

## Verification-environment note

Verilator (5.052) resolves tristate z to 0 when a net is read through
a task-argument copy; the simulation checks therefore evaluate the
`z` comparisons inline. This is a simulation-toolchain boundary
documented in the TB and implementation plan, not an RTL property.
