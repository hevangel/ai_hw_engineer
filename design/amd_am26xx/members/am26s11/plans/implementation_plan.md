# Am26S11 implementation plan

## Contract

AMD 1974 Data Book pages 4-39..4-44 (truth tables page 4-41; 1979
reprint pages 4-57..4-61): the Am26S11 is the non-inverting Am26S10 —
B̄ = enabled ? I : 'Z with the same always-active inverting receiver
Z̄ = !B̄ and pin map. Split driver/receiver ports per bus pin; the tie,
bias and party line are directed in simulation.

## Structure

One self-contained file `src/am26s11.sv`, structurally identical to the
verified am26s10 with the driver polarity per the truth table. No RTL
waivers needed.

## Verification mapping

Lint (Verilator `-Wall`, documented TB waivers), exhaustive
32-combination sweep plus directed party-line checks under Verilator
and xezim, formal bmc/prove/cover (`formal/am26s11.sby`), Yosys
synthesis with `check -assert`. Test and formal plans mirror the
am26s10 member with the polarity flipped.
