# Implementation plan

1. Download the Intel manual, independent SIMH model, and historical SCELBAL object code, recording source URLs and hashes.
2. Implement the 8008 ISA as a synthesizable synchronous finite-state machine with one-clock memory transactions and a visible instruction-retirement pulse. The sequencer computes a complete next state combinationally and commits every architectural element exactly once (single write-port discipline for the register file and stack), so out-of-range register indices are structurally impossible.
3. Build instruction, control-flow, I/O, interrupt, and authentic-software regressions. Compare against documented results or the external SIMH model, with exact PC checks. Emit an opcode histogram with the authentic-software vectors and report opcode-family coverage (see [the test plan](testplan.md)).
4. Prove the retirement contract, stack discipline, bus protocol, undefined-encoding no-effects, and ready freeze with SymbiYosys per [the formal plan](formal_plan.md); keep cover non-vacuous.
5. Run Verilator lint and simulation, SymbiYosys proof and cover, and Yosys synthesis. Record outcomes and remaining limitations in [the verification report](../report/final_report.md) and [the coverage report](../report/coverage_report.md).
