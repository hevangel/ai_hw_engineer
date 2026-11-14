# Am26LS32 test plan

Reference: 1979 Linear and Interface Data Book pages 4-40..4-44.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 1024 input combinations (four differential
   pairs plus the enable pair), asserting the driven values and the
   exact `z` high-impedance state per output.

## Formal (`formal/am26ls32.sby`)

Per-receiver assertions (contract, enable semantics, fail-safe) and
covers for the four enable-pair corners, both differential states per
receiver, ties enabled and disabled, and a mixed differential pattern.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
