# Am9080A verification report

Verified October 3, 2026 in `ai-hw-engineer:latest`, using Verilator 5.052,
Yosys 0.69, SymbiYosys/ABC/Z3 and xezim 0.11.0 with UVM 1800.2-2017.
Reproduce the complete observed flow:

```sh
sh design/amd_am9080/scripts/run_all.sh
```

## Observed results

- RTL `verilator --lint-only -Wall` and timed differential testbench lint:
  pass without warnings. No blanket lint-warning suppression.
- ALU: 16,842,752 exhaustive comparisons against the immutable external
  emulator, covering all operands and all 32 status combinations for eight
  binary operations, plus every value/status combination for INR, DCR, DAA,
  rotations and CMA. Only the independently sourced AMD ANA correction is
  applied to the Intel oracle. Zero failures.
- Instruction regression: all 244 documented opcodes over all 32 flag
  combinations, 7,808 cases and 78,048 exact retirement/next-instruction/effect
  checks. Includes SP wrap, direct-word wrap, both branch conditions, PSW,
  actual next fetched/executed instructions, and memory/I/O effects.
  Unused memory is HLT poison; no padding absorbs an incorrect PC. Every
  expected state is produced by the external artifact, not an RTL-derived ISS.
- Unmodified historical software: TST8080.COM (Microcosm Associates, 1980)
  passes with 661 retirement checks including ten explicit bootstrap
  instructions; 8080PRE.COM passes with 1,071 including the same bootstrap.
  Original program bytes and hashes are verified. PC, registers, flags,
  stack pointer, interrupt enable and memory/I/O effects agree at every
  checked retirement. The actual next instruction fetch is checked. Both
  success messages and full BDOS output match the independent oracle.
- UVM: 15 control/fault scenarios, 104 expected-state snapshots, 344 clock
  steps and 121 acknowledged transfers, zero UVM_ERROR/UVM_FATAL. Covers
  reach wait, HOLD, HALT, interrupt, invalid opcode and I/O. Checks include
  stalled transfers, completion-before-HOLD, reset retention, delayed EI,
  RST injection, three-byte CALL/NULL injection without PC increments,
  HOLD priority during HALT, disabled-interrupt HALT retention, all twelve
  unspecified opcodes and unsupported injected XTHL.
- Manufacturer historical code: the UVM CALL ISR executes the actual
  PUSH PSW/B/D/H, POP H/D/B/PSW, EI/RET skeleton from handbook 15-2 / PDF
  301, including Figure 15-3. A pending INT during EI must not preempt RET;
  the return PC and all saved registers/status are checked exactly.
- Formal: all six tasks pass. ALU depth-2 BMC, unbounded induction and 18
  reachable covers prove the independently derived arithmetic/flag equations.
  CPU depth-32 ABC BMC, unbounded SMT induction and eight reachable covers
  prove controller reset/retention, stall stability, HOLD/fault bus suppression,
  retirement and logical status-space properties. This is not a formal proof
  of every complete instruction; instruction semantics use the independent
  differential and historical-software regressions above.
- Synthesis: 3,356 cells including 397 in the combinational ALU; no latches,
  no warnings/errors, and Yosys `check -assert` passes.

## Verification findings and boundaries

The first instruction generator placed its initialization data across RST
vectors; a following undefined opcode correctly raised a model fault. Moving
the bootstrap to 0080 separated it from the restart entries and preserved
exact next-instruction checks. No RTL semantic change was needed.

SMT induction initially returned UNKNOWN from an unreachable state with
FAULT asserted while the controller was still in MEM_WR. Adding the proved
fault/state reachability invariant establishes induction without weakening
the existing assertions. No reachable RTL counterexample was found.

The supplied xezim/UVM runtime emits 23 `UVM/COMP/NAME` warnings for valid
ordinary component/library names (including `driver`, `scoreboard` and UVM
FIFO ports). They remain visible in the log; they are not suppressed or
reported as zero warnings. Functional UVM checks and covers complete with
zero errors/fatals. Standalone RTL/testbench Verilator lint is clean.

The core is a complete documented-instruction **functional reconstruction**
of Am9080A. Its ready/valid bus is not the original two-phase pin waveform,
and its implementation-step counts are not manufacturer T-state timings.
The unsuffixed earlier revision, electrical characteristics and unspecified
opcodes are not assigned invented guarantees. See the specification for the
reset adapter and explicit validity-fault boundary.
