# Am26LS31 test plan

Reference: 1979 Linear and Interface Data Book pages 4-36..4-39.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 64 input combinations, asserting driven
   values and the exact `z` state per output pair.

## Formal (`formal/am26ls31.sby`)

Driven contract and enable semantics in every state; covers for the
enable-pair corners, both differential pair states, the disabled state,
and a mixed data pattern.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
