# Am29323 verification report

Verified digital contract: the 32 × 32 multiplier array with exact
mixed-mode products (two's complement, unsigned, or mixed per TCX/TCY),
the 67-bit accumulator with PASS/ACCUMULATE/SHIFT AND ACCUMULATE
(shift right 32 with sign extension from the overflow bit, per the 1988
book's explicit definition), dual input registers per bus with
feedthrough, the FA word-slice geometry (Pi/Pi−1/Pi+31/Pi+32 per the
data-format figures, LSB-zero note included), RND, the temporary and
instruction registers, the output multiplexer with DISABLE, byte
even-parity checking/generation, and HARDERR driven-vs-observed
comparison.

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator 5.052, Yosys 0.69,
SymbiYosys/ABC. Run `sh design/amd_am29xxx/members/am29323/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Simulation: 8,069 lockstep drive cases (48,414 checks): directed
  sweeps over three product corners × TC mode × accumulator command
  with full slice readbacks under both FA and RND; T-register captures
  for all four Table 2 selections; mixed modes with ACCUMULATE and
  SHIFT AND ACCUMULATE flows and slice readback after every operation;
  the multiprecision 64 × 64 register-staging sequence; 6,000 random
  full-space drives with interleaved readback windows. Every drive —
  including readbacks — is stepped through by the external functional
  oracle; outputs are checked before each edge and the edge updates the
  model's registers.
- Formal: BMC depth 16 (smbtmc z3), unbounded ABC PDR (prove) and cover
  against an independently recomputed reference — command decode, FA
  slices, accumulator operations, output contract; per-register
  capture-discipline assertions for all seven register sets via an
  anyconst watched register; covers for every accumulator command, PSEL
  selection, FA, RND, FTP, slave mode, parity error and mixed mode.
- Synthesis: 11,161 cells with `check -assert` clean.

Bring-up findings recorded as verification-infrastructure lessons: the
driver's command-word unpack must mirror the generator's packing (a
reversed unpack silently turned ACCUMULATE into PASS and the readbacks
into T-register reads); random stimulus fields must be masked to port
widths or the model and DUT operate on different data; the lockstep
readback discipline (the model steps through readback windows) carries
over from the Am29334 bring-up.

## Limits

The accumulator command ACC = 10 is documented INVALID; the model holds
the accumulator (ledger). RND's exact addend and the FTP bypass position
are documented model choices (ledger). Electrical timing, the 80 ns
bipolar and 80/55 ns CMOS speed grades are outside the contract. The
datasheet's seven-cycle 64 × 64 claim is exercised as a register-staging
sequence, not a board-level performance measurement. Introduction-year
evidence: 1985 advanced information; no exact first-shipment date
asserted.
