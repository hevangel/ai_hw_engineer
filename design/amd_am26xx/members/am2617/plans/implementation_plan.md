# Am2617 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-82..4-85: four inverting
RS-232C receivers, OUT = !IN per receiver in the boolean line model.
Hysteresis, response-control bias and threshold levels are documented
and not modeled. Zero-delay combinational reconstruction.

## Structure

One self-contained file `src/am2617.sv`, four continuous assigns. No
waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^4 = 16 combination check under Verilator
  and xezim.
- Formal: `formal/am2617.sby` bmc/prove/cover — per-receiver inversion
  contract and covers for every per-receiver state and mixed patterns
  (depth 2 exhaustive for combinational logic).
- Synthesis: Yosys `synth -top am2617; check -assert`.
