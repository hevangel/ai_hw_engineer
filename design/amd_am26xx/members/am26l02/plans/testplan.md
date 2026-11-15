# Am26L02 test plan

Reference: AMD 1974 Data Book pages 4-27..4-32; 1979 selection guide
page 1-13.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

Identical stimulus plan to the Am2602 member (the digital contract is
the same published truth table): power-on quiescence, both Table I
trigger rows per channel, non-trigger combinations, exact pulse width,
retrigger extension, asynchronous clear dominance with spike
suppression, consumed edges, and channel independence.

## Formal (`formal/am26l02.sby`)

bmc/cover with per-channel reference-model equality and pulse-width
properties plus the full cover set; prove with the unbounded
complementarity and clear-dominance properties; every cover must be
reached.

## Acceptance

Lint clean (documented RTL waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
