# Am26S10 implementation plan

## Contract

AMD 1974 Data Book pages 4-39..4-44 (reprinted identically in the 1979
book pages 4-57..4-61): four open-collector inverting bus drivers
gated by one active-low enable, plus four always-active inverting bus
receivers reading the same nets: B̄ = enabled ? !I : 'Z; Z̄ = !B̄.
Bus pins modeled with split driver/receiver ports (see the spec's
port-structure note); the tie, pull-up bias and party-line resolution
are directed in simulation.

## Structure

One self-contained file `src/am26s10.sv`: enable, four tristate driver
assigns, four receiver inverters. No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall` (TB waivers: BLKSEQ/PROCASSINIT/UNUSEDSIGNAL/
  DECLFILENAME/PINCONNECTEMPTY — the party fixtures leave unused
  channel pins open).
- Simulation: exhaustive 32-combination sweep with pull-up bias, plus
  the directed party-line section (two instances, one shared bus,
  handover and released-idle checks), under Verilator and xezim.
- Formal: `formal/am26s10.sby` bmc/prove/cover — driver contract and
  release (=== z), receiver contract with harness-driven bus, covers
  for the truth-table rows and all-driven/all-released states (depth 2
  exhaustive for combinational logic).
- Synthesis: Yosys `synth -top am26s10; check -assert`.
