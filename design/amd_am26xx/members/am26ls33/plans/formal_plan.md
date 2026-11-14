# Am26LS33 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-40..4-44 (shared
Am26LS32 · Am26LS33 sheet); spec.

## Properties

Identical to the Am26LS32 formal plan: driven contract with `===`
exactness, enable semantics (all outputs exactly `z` when both enables
are released), and fail-safe ties — all in every state.

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

The four enable-pair corners, both differential states per receiver,
ties enabled and disabled, and a mixed differential pattern.
