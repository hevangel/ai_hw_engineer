# Implementation plan

1. Download the Intel manual, independent SIMH model, and historical SCELBAL object code, recording source URLs and hashes.
2. Implement the 8008 ISA as a synthesizable synchronous finite-state machine with one-clock memory transactions and a visible instruction-retirement pulse.
3. Build instruction, control-flow, I/O, interrupt, and authentic-software regressions. Compare against documented results or the external SIMH model, with exact PC checks.
4. Run Verilator lint and simulation, SymbiYosys proof and cover, and Yosys synthesis. Record outcomes and remaining limitations.
