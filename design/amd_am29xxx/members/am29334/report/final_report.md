# Am29334 verification report

Verified digital contract: 64 × 18 dual-access four-port register file
with per-byte (9-bit) write enables, the on-chip read/write address
multiplexer driven by the common write enables, read-during-write
transparency, transparent output latches with hold, and three-state
output enables. Fully asynchronous part: no clock, no reset.

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator 5.052, Yosys 0.69,
SymbiYosys/Z3/ABC. Run `sh design/amd_am29xxx/members/am29334/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Simulation: 27,210 lockstep drive cases (82,065 checks): directed
  byte-enable sweeps over address corners {0, 1, 31, 32, 62, 63} with
  latch-enable and output-enable combinations, cross-port
  simultaneous-write cases over all byte-enable combinations, transparency
  windows, and 20,000 random full-space drives with interleaved readback
  windows on both ports. Every drive the testbench performs — including
  readback windows — is stepped through by the external functional
  oracle, so output-latch history stays in lockstep (this lockstep rule
  was the bring-up finding: readback drives update the DUT latches and
  the oracle must model them).
- Formal BMC depth 16 (smtbmc z3): PASS. Unbounded ABC PDR (prove):
  PASS. Cover (smtbmc z3): PASS with zero unreached statements — byte
  and full writes, write windows, transparency, cross-port visibility
  and three-state combinations. Two anyconst watched cells are shadowed
  per byte lane (seeded on the first formal cycle, then following the
  documented write behavior including the A-side-wins same-cell-byte
  collision resolution).
- Synthesis: latch-based design (the real device is asynchronous RAM
  plus transparent latches); Yosys `check -assert` reports zero problems.

Two modeling reworks were needed, not suppressions: two sequenced writes
into one latch memory form a read-modify-write combinational loop under
latch semantics, so storage is per-cell decoded latches (each cell's data
input is a pure pin function, resolving the both-sides collision with the
A side winning that cell); and byte-merge writes on a word array have the
same loop hazard, so storage is split into two independent byte-lane
arrays.

## Limits

Uninitialized and partially written cells read as undefined data
(verification masks value checks, never enable/address checks). Power-up
contents, the 24 ns electrical access time, and the board-level 32×36
configuration pattern (datasheet Figure 4) are outside the contract.
The both-sides-same-cell-and-byte collision value is a documented model
choice, not datasheet behavior. Introduction-year evidence: 1985 advanced
information; final datasheet Amendment 10 in the 1988 data book; no exact
first-shipment date asserted.
