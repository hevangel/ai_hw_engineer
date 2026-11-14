# Am26LS30 test plan

Reference: 1979 Linear and Interface Data Book pages 4-30..4-35
(function table page 4-34).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of data × mode × slew-pin toggling (64 checks)
   against both published function tables, with inline exact-`z`
   assertions for the disabled RS-422 pair states.

## Formal (`formal/am26ls30.sby`)

Both function tables asserted row-by-row in every state; covers for
each table row (RS-422 enabled/disabled per pair, RS-423 data
combinations) and slew-pin independence.

## Acceptance

Lint clean, both simulators pass, all formal tasks PASS with every
cover reached, Yosys `check -assert` clean.
