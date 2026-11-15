# Am26LS29 test plan

Reference: 1979 Linear and Interface Data Book pages 4-26..4-29.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of data × enable × slew-pin toggling (64 checks)
   with exact `z` assertions, proving both the enable contract and the
   slew-pin boolean independence.

## Formal (`formal/am26ls29.sby`)

Enable semantics and driven contract in every state; covers for the
disabled state, per-driver enabled states, a mixed data pattern, and
slew-pin independence.

## Acceptance

Lint clean, both simulators pass, all formal tasks PASS with every
cover reached, Yosys `check -assert` clean.
