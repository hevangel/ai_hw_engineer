# Am2602 implementation plan

## Contract

AMD 1974 Data Book, catalog pages 4-21 to 4-26: dual retriggerable
resettable monostable. Per channel the trigger network is
N = !Ī0 ∨ I1 (Ī0 pin active low, I1 pin active high; Table I rows: Ī0
falling with I1 low, I1 rising with Ī0 high) with an active-low
asynchronous direct clear; Q pulses HIGH. External RC sets the
electrical width; the digital abstraction counts `PULSE_CYCLES`
reference-clock cycles.

## Structure

One self-contained file `src/am2602.sv`; the two independent monostables
are two register instances of the same documented behavior (the repo
one-module-per-file rule keeps them in one module rather than a shared
submodule). Per channel:

- combinational trigger network and clear sampling,
- two-deep edge history (consumed edges under a held clear never fire),
- down-counter with asynchronous direct clear and retrigger reload,
- quiescent-state declaration initializers (documented assumption).

Localized lint waivers: `SYNCASYNCNET` (the async clear pin is sampled
synchronously) and `PROCASSINIT` (register declaration initializers),
each commented in the source.

## Verification mapping

- Lint: Verilator `-Wall`; TB with documented waivers.
- Simulation: `tb/tb_top.sv` walks both Table I rows per channel,
  non-trigger combinations, pulse width, retrigger extension, async
  clear dominance/spike suppression, consumed edges, and channel
  independence (both channels running, one cleared mid-run), under
  Verilator and xezim.
- Formal: `formal/am2602.sby` bmc/prove/cover with per-channel reference
  models (scoping as in the family formal plan).
- Synthesis: Yosys `synth -top am2602; check -assert`.
