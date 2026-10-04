# Am9102 verification report

Verified October 3, 2026 in `ai-hw-engineer:latest` with Verilator 5.052,
Yosys 0.69, SymbiYosys/ABC, Z3 and xezim 0.11.0. Reproduce with
`sh design/amd_am9102/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: RTL and timed testbench pass without warnings.
- Formal: depth-16 ABC BMC, unbounded ABC PDR, and all five Z3 covers pass.
  An arbitrary `anyconst` address proves last-write/read agreement and
  retention through other-address writes and standby, without initialization
  or assumptions on input values. Covers reach both data values, unrelated
  writes, standby recovery, and the invalid selected-standby mode.
- Simulation: 8,192 exhaustive control/data cases, 100,352 reads (including
  address-bit neighbors, March C- operations and complete pattern/standby
  scans), 2,048 transparent DIN updates and 4,097 two-chip shared-bus checks
  pass with zero failures. Exact counts and watchdog are enforced.
- Yosys synthesis and `check -assert` pass. All 1,056 synthesis warnings are
  intentional: 32 bank memories are replaced by registers and 1,024
  asynchronous latch bits are inferred. No unintended state is required.

The final 32x32 storage implementation was checked through the complete flow.
Earlier flat representations were functionally valid but expensive for
synthesis lowering or event simulation; banking preserves the complete
1024-address contract and corresponds to the manufacturer's cell-array size.

The core is a binary zero-delay reconstruction. The caller owns original
write setup/hold, standby deselection, voltage limits and one-TCYCLE recovery.
Selected standby output is explicitly invalid; the model does not invent its
physical electrical state. No real CPU software requirement applies to RAM.
