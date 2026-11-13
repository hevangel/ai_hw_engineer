# Am26L02 implementation plan

## Contract

AMD 1974 Data Book, catalog pages 4-27 to 4-32 (truth table page 4-30,
identical to the Am2602's page 4-25; 1979 selection guide: "Low-Power
version 2602"). Per channel the trigger network is N = !Ī0 ∨ I1 with an
active-low asynchronous direct clear; Q pulses HIGH. Electrical timing
T = 0.33·Rx·Cx·(1 + 3.2/Rx), Rx 20 kΩ to 200 kΩ, is documented and not
modeled; the abstraction counts `PULSE_CYCLES` reference cycles.

## Structure

One self-contained file `src/am26l02.sv`, organizationally identical to
the Am2602 implementation (the digital contracts are the same published
truth table): per channel a combinational trigger network, a two-deep
edge history (consumed edges under a held clear never fire), a
down-counter with asynchronous clear and retrigger reload, and quiescent
declaration initializers.

Localized lint waivers (`SYNCASYNCNET`, `PROCASSINIT`) are commented in
the source.

## Verification mapping

Lint (Verilator `-Wall`), directed simulation of the full stimulus plan
under Verilator and xezim, formal bmc/prove/cover with per-channel
reference models (`formal/am26l02.sby`), Yosys synthesis with
`check -assert`. The test and formal plans state the detailed mapping.
