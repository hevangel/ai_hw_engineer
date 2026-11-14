# Am26S12 implementation plan

## Contract

AMD 1974 Data Book pages 4-39..4-44 qualified by the 1979 sheet pages
4-62..4-66: four open-collector inverting bus drivers behind an
active-low two-input AND enable (both E pins low), four always-active
inverting receivers reading the same nets: B̄ = enabled ? !I : 'Z;
Z̄ = !B̄. Split driver/receiver ports per bus pin; tie, bias and
party line directed in simulation.

## Shared source (revision rule)

Per the parent issue, the S12 and S12A grades share one source file:
`src/am26s12.sv` with an integer `REVISION` parameter (0 = S12, 1 =
S12A) that selects the documented receiver-threshold pair and is
validated at elaboration together with the datasheet's >0.4 V margin
guarantee; the digital function is grade-independent. The
[Am26S12A member](../am26s12a/spec/spec.md) verifies the same source at
REVISION 1 with its own lint/formal/sim/synth flows.

## Verification mapping

- Lint: Verilator `-Wall` (TB waivers documented in the scripts).
- Simulation: exhaustive 64-combination dual-enable sweep with pull-up
  bias plus directed party-line checks, under Verilator and xezim.
- Formal: `formal/am26s12.sby` bmc/prove/cover at REVISION 0 — driver
  contract with dual-enable AND, release (=== z), receiver contract,
  covers per truth-table row class (depth 2 exhaustive).
- Synthesis: Yosys `chparam -set REVISION 0; synth -top am26s12;
  check -assert`.
