# Am26123 implementation plan

## Contract

AMD 1974 Data Book, catalog pages 4-87 to 4-92: dual retriggerable
resettable monostable, 74123-compatible. Per channel the trigger network
is N = !A && B (A pin active low, B pin active high) with an active-low
asynchronous clear; Q pulses HIGH. External CEXT/REXT networks set the
electrical width; the abstraction counts `PULSE_CYCLES` reference-clock
cycles.

## Structure

One self-contained file `src/am26123.sv`: per channel a combinational
trigger network, a two-deep edge history (consumed edges under a held
clear never fire), a down-counter with asynchronous clear and retrigger
reload, and quiescent declaration initializers.

Localized lint waivers (`SYNCASYNCNET`, `PROCASSINIT`) are commented in
the source.

## Verification mapping

Lint (Verilator `-Wall`), directed simulation of the truth-table rows
and timing behaviors under Verilator and xezim, formal bmc/prove/cover
with per-channel reference models (`formal/am26123.sby`), Yosys
synthesis with `check -assert`.
