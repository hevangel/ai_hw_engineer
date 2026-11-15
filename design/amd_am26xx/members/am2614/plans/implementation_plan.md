# Am2614 implementation plan

## Contract

AMD 1974 Data Book pages 4-45..4-50 (reprinted identically in the 1979
book pages 4-67..4-71): four independent 3-input inverting drivers, two
data inputs and one common strobe per pair,
OUT = !(IN_x & IN_y & STROBE_pair). Zero-delay combinational
reconstruction; the electrical envelope is documented in the spec.

## Structure

One self-contained file `src/am2614.sv`, four continuous assigns.
No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^10 = 1024 combination check plus pair
  independence, under Verilator and xezim.
- Formal: `formal/am2614.sby` bmc/prove/cover — per-output NAND
  contract, strobe-idle property, covers for enabled/disabled line
  states and asymmetric data (depth 2 is exhaustive for a purely
  combinational design).
- Synthesis: Yosys `synth -top am2614; check -assert`.
