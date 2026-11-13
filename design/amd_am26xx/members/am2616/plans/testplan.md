# Am2616 test plan

Reference: 1979 Linear and Interface Data Book pages 4-78..4-82.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 256 input combinations against the four
   per-driver contracts.

## Formal (`formal/am2616.sby`)

Per-driver assertions (contract, inhibit dominance, inhibit-low data
path) and covers for inhibited and transmitting states of each driver,
mixed inhibit/transmit states, and all-four-inhibited mark state.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
