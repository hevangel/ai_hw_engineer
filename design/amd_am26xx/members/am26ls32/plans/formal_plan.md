# Am26LS32 formal plan

Reference: 1979 Linear and Interface Data Book pages 4-40..4-44; spec.

## Properties

1. Per-receiver driven contract: out == (IN+ >= IN−) when enabled
   (all modes; `===` so the z state is distinguished).
2. Enable semantics: all four outputs are exactly `z` when
   !(ENABLE low || ENABLE2 high) (all modes).
3. Fail-safe: enabled outputs are HIGH on open-line ties (all modes).

## Scope

Purely combinational: depth-2 bmc is exhaustive over the input space
and prove is unbounded without induction difficulty.

## Covers (non-vacuity)

The four enable-pair corners (including the disabled corner and the
two enabled ones), both differential states per receiver, ties enabled
and disabled, and a mixed differential pattern across the four
receivers.
