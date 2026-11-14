# Am26LS32 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-40..4-44: four non-inverting
differential receivers, 3-state outputs, OR-ed complementary enables
(pin 4 low or pin 12 high), fail-safe outputs-high on open inputs:
comp = (IN+ > IN−), out = enabled ? comp : 'Z. Zero-delay
reconstruction; sensitivity/hysteresis/delay documented, not modeled.

## Structure

One self-contained file `src/am26ls32.sv`: an enable pair, four
differential decisions, four 3-state assigns. No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^10 = 1024 combination check including the
  `z`-state assertions under Verilator and xezim.
- Formal: `formal/am26ls32.sby` bmc/prove/cover — per-receiver
  contract, enable semantics, fail-safe ties, covers for the enable
  pair corners, differential states, ties, and mixed patterns (depth 2
  exhaustive for combinational logic).
- Synthesis: Yosys `synth -top am26ls32; check -assert`.
