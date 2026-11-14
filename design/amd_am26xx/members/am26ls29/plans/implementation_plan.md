# Am26LS29 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-26..4-29: four non-inverting
3-state drivers gated by one active-low enable (out = enable ? in : 'Z).
Slew-rate-control pins are analog-only and exposed as documented unused
inputs. Zero-delay reconstruction.

## Structure

One self-contained file `src/am26ls29.sv`: enable plus four 3-state
assigns; the `_unused_sr` term documents the analog pins. No waivers
needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 64-combination sweep (data × enable × slew
  toggling) with exact `z` assertions under Verilator and xezim.
- Formal: `formal/am26ls29.sby` bmc/prove/cover — enable semantics,
  driven contract, covers for enabled/disabled states, per-driver
  states, mixed patterns, and slew-pin independence (depth 2
  exhaustive).
- Synthesis: Yosys `synth -top am26ls29; check -assert`.
