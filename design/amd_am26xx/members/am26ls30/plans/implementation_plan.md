# Am26LS30 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-30..4-35: MODE-selected
configuration — RS-423 quad single-ended non-inverting always-driven
outputs (mode high), or RS-422 dual differential pairs with
complementary outputs and active-low enables on the B/C pins (mode
low), verified row-by-row against the published function table.
Slew-rate-control pins are analog-only. Zero-delay reconstruction.

## Structure

One self-contained file `src/am26ls30.sv`: per pair a 422-path
(ternary with z), a 423-path (direct), and a mode mux on the output.
The `_unused_sr` term documents the analog pins. No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 64-combination sweep (data × mode × slew
  toggling) with inline exact-`z` checks. NOTE: Verilator resolves
  tristate z to 0 across task-argument copies, so the z checks are
  evaluated inline in the loop context (documented in the TB and the
  repro note).
- Formal: `formal/am26ls30.sby` bmc/prove/cover — both function tables
  row-by-row, covers for every table row, slew-pin independence, both
  modes (depth 2 exhaustive).
- Synthesis: Yosys `synth -top am26ls30; check -assert`.
