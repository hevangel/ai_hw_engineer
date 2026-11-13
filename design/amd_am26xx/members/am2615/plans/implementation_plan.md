# Am2615 implementation plan

## Contract

AMD 1974 Data Book pages 4-51..4-56 (reprinted identically in the 1979
book pages 4-72..4-77): per receiver OUT = !(COMP && STROBE), COMP the
differential comparator decision. Strobe pins 3/13 gate the output;
response-control pins 4/12 carry no boolean effect. The binary line
model resolves the equal-inputs (open-line) code to COMP = 1 per the
documented Am2615 fail-safe; the pin-label swap in the 1974 loading
rules table is recorded and resolved in the spec.

## Structure

One self-contained file `src/am2615.sv`, two continuous assigns per
receiver (differential decision + strobe gate). No waivers needed.

## Verification mapping

- Lint: Verilator `-Wall`, no waivers.
- Simulation: exhaustive 2^6 = 64 combination check under Verilator and
  xezim.
- Formal: `formal/am2615.sby` bmc/prove/cover — per-receiver contract,
  strobe-idle property, fail-safe tie behavior, covers for both
  differential states per receiver, strobe-disabled states, ties, and
  receiver independence (depth 2 exhaustive for combinational logic).
- Synthesis: Yosys `synth -top am2615; check -assert`.
