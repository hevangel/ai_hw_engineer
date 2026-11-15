# Am2615 test plan

Reference: AMD 1974 Data Book pages 4-51..4-56; spec assumption ledger.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of all 64 input combinations against the per-
   receiver contract with the fail-safe tie resolution.
2. Receiver independence is implied by the exhaustive check.

## Formal (`formal/am2615.sby`)

Per-receiver assertions (contract, strobe-idle, fail-safe ties, defined
differential states) and covers for both differential states per
receiver, strobe-disabled states, tie states strobed and idle, and
independent strobing of the two receivers.

## Acceptance

Lint clean, both simulators pass the exhaustive sweep, all formal tasks
PASS with every cover reached, Yosys `check -assert` clean.
