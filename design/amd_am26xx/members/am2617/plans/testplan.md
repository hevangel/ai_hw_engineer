# Am2617 test plan

Reference: 1979 Linear and Interface Data Book pages 4-82..4-85.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 16 input combinations against the inversion
   contract per receiver.

## Formal (`formal/am2617.sby`)

Per-receiver inversion assertions and covers for every per-receiver
state, all-high/all-low patterns, and a mixed pattern.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
