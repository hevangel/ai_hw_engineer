# Am2614 test plan

Reference: AMD 1974 Data Book pages 4-45..4-50.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 2^10 input combinations against the four
   3-input NAND contracts.
2. Pair independence is implied by the exhaustive check (all pair
   combinations appear).

## Formal (`formal/am2614.sby`)

Per-output NAND assertions, strobe-idle property (strobe low forces the
pair's outputs high), and covers for: strobe-disabled pair, asserted
pair, strobe-enabled idle-high pair with data low, mixed pairs, and
asymmetric single-data-low states. Depth-2 bmc is exhaustive for a
combinational design; prove is unbounded.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
