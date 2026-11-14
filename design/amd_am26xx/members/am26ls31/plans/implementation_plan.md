# Am26LS31 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-36..4-39 (first printed in
the 1977 book): four differential drivers with complementary 3-state
outputs and OR-ed enables — Y = IN, Z = !IN when enabled, both 'Z when
disabled. Zero-delay reconstruction.

## Structure

One self-contained file `src/am26ls31.sv`: enable pair plus four
3-state output pairs. No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^6 = 64 combination check with exact `z`
  assertions under Verilator and xezim.
- Formal: `formal/am26ls31.sby` bmc/prove/cover — driven contract,
  enable semantics, covers for the enable corners, differential pairs,
  disabled state and mixed data (depth 2 exhaustive).
- Synthesis: Yosys `synth -top am26ls31; check -assert`.
