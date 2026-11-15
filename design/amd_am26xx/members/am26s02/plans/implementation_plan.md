# Am26S02 implementation plan

## Contract

AMD 1974 Data Book preliminary sheet (catalog pages 4-33 to 4-38),
qualified against the final data in the 1978 Schottky data book (pages
4-50 to 4-53): per channel the trigger network is N = !Ī0 ∨ I1 with an
active-low asynchronous direct clear; Q pulses HIGH. Schottky electrical
parameters (28 ns–∞ range, Rx ≤ 100 kΩ, PNP inputs) are documented and
not modeled; the abstraction counts `PULSE_CYCLES` reference cycles.

## Structure

One self-contained file `src/am26s02.sv`, organizationally identical to
the verified Am2602/Am26L02 implementations (the function table is the
same): per channel a combinational trigger network, a two-deep edge
history, a down-counter with asynchronous clear and retrigger reload,
and quiescent declaration initializers.

Localized lint waivers (`SYNCASYNCNET`, `PROCASSINIT`) are commented in
the source.

## Verification mapping

Lint (Verilator `-Wall`), directed simulation of the family stimulus
plan under Verilator and xezim, formal bmc/prove/cover with per-channel
reference models (`formal/am26s02.sby`), Yosys synthesis with
`check -assert`.
