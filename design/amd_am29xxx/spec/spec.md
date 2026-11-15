# Am29xxx series scope

Canonical issue [#126](https://github.com/hevangel/ai_hw_engineer/issues/126)
tracks three device groups as distinct contracts under one series card:

1. **29K RISC processors** — Am29000, Am29005, Am29030/35/40, Am29050 and
   the Am292xx embedded microcontrollers. CPU-class members: qualified
   against real historical 29K code, not only per-instruction tests, per
   the repository's escaped-defect rules.
2. **Am29300/Am29C300 microprogrammable family** — Am29323/29C323
   multiplier, Am29325/29C325 floating-point processor, Am29C327
   double-precision FPP, Am29331/29C331 sequencer, Am29332/29C332 ALU,
   Am29334/29C334 register file, Am29337 bounds checker, Am29338 byte
   queue, Am29434 ECL register file. Anchored by the 1985 Am29300 Family
   Handbook (advanced information) and the 1988 Am29C300/29300 Data Book
   (final datasheets); each member binds its own source.
3. **Am295xx signal-processing support** — Am29501(A) multiport
   processors, Am29509/29510/29516/29517 multipliers, Am29520/21/24/25
   pipeline registers, Am29526–29529 trigonometric generators, Am29540 FFT
   address sequencer. Anchored by the 1986 Am29500 Family Handbook.

## Series rules

- One canonical folder, one member subfolder and one member sub-issue per
  physical chip. Documented base and A revisions share one SystemVerilog
  source with an explicit revision selection; each contract is verified
  separately.
- Member acceptance follows the repository gates: sourced specification
  with an assumption ledger, synthesizable SystemVerilog, independent
  functional and timing verification, lint, simulation, formal assertions
  with reachable covers, synthesis, and a report of results and limits.
- CMOS (29C) and ECL variants are separate member issues sharing bipolar
  RTL where the vendors document identical function; process-dependent
  timing stays outside the digital contract.
- CPU members must run real historical software as part of their
  verification before sign-off.

The Am29331 member is implemented and verified; every other member row is
an explicit inventory gap with no implementation asserted.
