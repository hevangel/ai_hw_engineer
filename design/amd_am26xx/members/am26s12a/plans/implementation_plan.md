# Am26S12A implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-62..4-66: functionally
identical to the Am26S12 with the revised receiver hysteresis grade
(VIH 2.25 V typ / VIL 1.2 V typ). One truth table across both grades;
the digital contract is grade-independent.

## Shared source (revision rule)

Per the parent issue, the S12 and S12A grades share one source file:
[../am26s12/src/am26s12.sv](../am26s12/src/am26s12.sv) with the
`REVISION` parameter; this member instantiates it at REVISION 1 and
verifies the contract separately with its own lint/formal/sim/synth
flows. The elaboration-time check pins the documented S12A threshold
pair and the >0.4 V margin guarantee.

## Verification mapping

- Lint: Verilator `-Wall` with `-GREVISION=1` on the shared source
  (TB waivers documented in the scripts).
- Simulation: exhaustive 64-combination dual-enable sweep with pull-up
  bias plus directed party-line checks, under Verilator and xezim,
  against the REVISION 1 instance.
- Formal: `formal/am26s12a.sby` bmc/prove/cover — same properties as
  the am26s12 plan, evaluated on the REVISION 1 instance.
- Synthesis: Yosys `chparam -set REVISION 1; synth -top am26s12;
  check -assert`.
