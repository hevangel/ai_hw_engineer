# Am26L123 test plan

Reference: 1979 selection guide page 1-13; Am26123 truth table (1974
Data Book page 4-91) per the spec composition assumption.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

Am26123 stimulus plan (same truth table): power-on quiescence, both
trigger rows per channel, non-trigger rows, exact pulse width, retrigger
extension, asynchronous clear dominance with spike suppression and
consumed edges, channel independence.

## Formal (`formal/am26l123.sby`)

bmc/cover with per-channel reference-model equality and pulse-width
properties plus the full cover set; prove with the unbounded
complementarity and clear-dominance properties; every cover must be
reached.

## Acceptance

Lint clean (documented RTL waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
