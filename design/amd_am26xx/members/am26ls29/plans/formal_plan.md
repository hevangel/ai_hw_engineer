# Am26LS29 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-26..4-29; spec.

## Properties

1. Enable semantics with `===` exactness: all four outputs exactly `z`
   when the enable is released; driven values equal the inputs when
   asserted (all modes).
2. Slew-pin independence: the contract holds for arbitrary slew-pin
   values (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

Disabled state, per-driver enabled high/low states, a mixed data
pattern, and two opposite slew-pin patterns over identical data.
