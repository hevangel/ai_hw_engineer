# Am26LS31 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-36..4-39; spec.

## Properties

1. Driven contract with `===` exactness: Y == IN, Z == !IN when
   enabled (all modes).
2. Enable semantics: all eight outputs exactly `z` when both enables
   are released (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

The four enable-pair corners, both states of each differential pair
(Y/Z complement), the disabled state, and a mixed data pattern.
