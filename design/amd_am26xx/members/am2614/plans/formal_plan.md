# Am2614 formal plan

Reference: AMD 1974 Data Book pages 4-45..4-50; spec.

## Properties

1. Per-output NAND contract, formulated independently of the RTL
   (all modes).
2. Strobe-idle: a low strobe forces its pair's outputs high (all modes).

## Scope

The part is purely combinational: every assertion is a combinational
property of the current inputs, so the depth-2 bmc explores all input
combinations and prove carries them unbounded without induction
difficulty.

## Covers (non-vacuity)

Strobe-disabled pair high, enabled asserted pair low, enabled pair
idle-high with data low (per pair), mixed pairs (A disabled while B
asserts), and asymmetric data (one data input low, the other high) on
both pairs.
