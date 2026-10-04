# Am3101 verification report

Verified on October 3, 2026 in `ai-hw-engineer:latest` with Verilator
5.052, Yosys 0.69, SymbiYosys/ABC and Z3. Reproduce with
`sh design/amd_am3101/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: RTL and timed testbench pass without warnings.
- Formal: 16-step ABC BMC, unbounded ABC PDR proof, and all three Z3
  non-vacuity covers pass. An arbitrary `anyconst` address checks write/read
  history and retention across writes to other addresses without initializing
  the DUT memory. Defined output modes and the unspecified-mode mask are checked.
- Simulation: 1,024 control/data cases, 16,912 memory reads, 256 transparent
  data updates, and 33 two-chip bank checks pass with zero failures.
- Synthesis: 243 cells including 64 latch bits, no errors, and
  `check -assert` passes. The 17 warnings are the expected memory-to-register
  replacement and 16 intentional four-bit asynchronous storage latches.

SMT temporal induction initially returned UNKNOWN because it did not establish
the memory/history invariant from arbitrary induction states. ABC PDR proved
the same properties without weakening them or changing storage behavior.

The original truth-table X row remains explicitly masked, and unwritten
storage is not initialized. The latch-based asynchronous core requires
proper physical write setup/hold; electrical behavior is outside scope.
