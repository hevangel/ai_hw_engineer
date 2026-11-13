# Am26S02 test plan

Reference: AMD 1974 Data Book pages 4-33..4-38 (preliminary) qualified
by the 1978 Schottky data book pages 4-50..4-53 (final).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

Family stimulus plan: power-on quiescence, both function-table trigger
rows per channel, non-trigger combinations, exact pulse width, retrigger
extension, asynchronous clear dominance with spike suppression,
consumed edges, and channel independence.

## Formal (`formal/am26s02.sby`)

bmc/cover with per-channel reference-model equality and pulse-width
properties plus the full cover set; prove with the unbounded
complementarity and clear-dominance properties; every cover must be
reached.

## Acceptance

Lint clean (documented RTL waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
