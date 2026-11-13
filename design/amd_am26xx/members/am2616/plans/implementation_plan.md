# Am2616 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-78..4-82: four inverting
RS-232C/MIL-188C drivers; driver A has two data inputs, B/C/D one each;
per-driver active-high inhibit forces the output to mark (LOW):
out_a = !((in_a1 && in_a2) || inhibit_a); out_b/c/d = !(in || inhibit).
Zero-delay combinational reconstruction.

## Structure

One self-contained file `src/am2616.sv`, four continuous assigns. No
waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^8 = 256 combination check under Verilator
  and xezim.
- Formal: `formal/am2616.sby` bmc/prove/cover — per-driver contract,
  inhibit-forces-mark property, inhibit-low data-path property, covers
  for inhibited and transmitting states per driver and all-inhibited
  (depth 2 exhaustive for combinational logic).
- Synthesis: Yosys `synth -top am2616; check -assert`.
