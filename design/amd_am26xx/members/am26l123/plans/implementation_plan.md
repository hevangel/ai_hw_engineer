# Am26L123 implementation plan

## Contract

1979 selection guide (page 1-13): "Low-Power version 26123, tpw = 120 ns
to ∞" — the digital function equals the Am26123 truth table (1974 Data
Book pages 4-87..4-92): N = !A && B per channel with an active-low
asynchronous clear; Q pulses HIGH. The low-power electrical envelope is
documented and not modeled; the abstraction counts `PULSE_CYCLES`
reference-clock cycles.

## Structure

One self-contained file `src/am26l123.sv`, organizationally identical to
the verified Am26123 implementation (same published truth table): per
channel a combinational trigger network, a two-deep edge history, a
down-counter with asynchronous clear and retrigger reload, and quiescent
declaration initializers.

Localized lint waivers (`SYNCASYNCNET`, `PROCASSINIT`) are commented in
the source.

## Verification mapping

Lint (Verilator `-Wall`), directed simulation of the Am26123 stimulus
plan under Verilator and xezim, formal bmc/prove/cover with per-channel
reference models (`formal/am26l123.sby`), Yosys synthesis with
`check -assert`.
