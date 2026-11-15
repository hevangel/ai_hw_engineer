# Am2600 implementation plan

## Contract

AMD 1974 Data Book, catalog pages 4-15 to 4-20: single retriggerable
monostable, trigger network N = (!Ī0 ∨ !Ī1) · I2 · I3 · I4, dual
active-low asynchronous clears, Q pulses HIGH, Q̄ complementary. External
RC sets the electrical width (T = 0.32·Rx·Cx·(1+3.7/Rx) ns); the digital
abstraction counts `PULSE_CYCLES` reference-clock cycles (spec records the
mapping and the assumption ledger).

## Structure

One self-contained file `src/am2600.sv`:

- combinational trigger network and effective clear,
- two-deep edge history so an edge consumed under a held clear never
  fires (documented inhibit-while-cleared behavior),
- down-counter with asynchronous direct clear, retrigger reloads the full
  width,
- `q_o`/`q_n_o` derived from the running flag; register initializers
  realize the documented quiescent power-up modeling assumption.

The synchronous sampling of the asynchronous clear pin requires one
localized `SYNCASYNCNET` lint waiver, commented in the source.

## Verification mapping

- Lint: Verilator `-Wall`, RTL without waivers; TB with documented waivers.
- Simulation: self-checking `tb/tb_top.sv` walking every Table I trigger
  row, non-trigger combinations, pulse width, retrigger extension, async
  clear termination, held-clear spike suppression and consumed-edge
  behavior, run under Verilator and xezim.
- Formal: `formal/am2600.sby` tasks bmc/prove/cover with an independent
  reference model; scoping and the bounded-completeness argument are
  recorded in the props header and the formal plan.
- Synthesis: Yosys `synth -top am2600; check -assert`.
