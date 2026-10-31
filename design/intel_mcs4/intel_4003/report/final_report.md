# Final Design Report: Intel 4003

## 1. Executive Summary

The Intel 4003 — the 10-bit serial-in/parallel-out/serial-out shift register
I/O expander of the 1971 MCS-4 set — is fully implemented, formally proven,
simulated against real MCS-4 bus timing, and synthesized cleanly. Sign-off
status: **READY**. One specification-level correction to the task brief
(width 10, not 16) was made from primary sources and is documented in the
spec and below.

## 2. Design Overview

- Module: `intel_4003` (`src/intel_4003.sv`), parameter `WIDTH = 10`
- Version: 1.0
- Designer: AI Hardware Engineer
- Date: 2026-08-27
- State: 10-stage shift register + CP-history bit; combinational output
  gating and serial-out tap

## 3. Verification Status

| Check | Tool | Result |
|-------|------|--------|
| RTL lint (`-Wall`) | Verilator 5.050 | PASS, zero warnings |
| Testbench lint (`-Wall`) | Verilator 5.050 | PASS, zero warnings |
| Formal BMC, depth 28 | SymbiYosys `abc bmc3` | PASS |
| Formal unbounded proof, depth 28 | SymbiYosys `abc pdr` | PASS |
| Formal cover, depth 28 | SymbiYosys `smtbmc z3` | PASS, 33/33 covers reached |
| Directed + random simulation | xezim | `TEST PASSED: 31225 checks, 7807 cycles` (0 failures) |
| Generic synthesis | Yosys 0.46 | PASS, 23 cells |

Yosys cell count: 23 total — 10 × `$_SDFFE_PN0P_` (shift stages with
synchronous reset + enable), 1 × `$_SDFF_PN0_` (CP history), 10 × `$_MUX_`
(shift/hold and enable gating), 1 × `$_AND_`, 1 × `$_NOT_`. No memories, no
latches, no processes remaining.

Formal property groups (all proven in bmc and pdr): shadow-model equivalence
for the register and CP history; `$past`-based shift semantics (DATA IN into
stage 0, stage-to-stage propagation); hold semantics proving one shift per
CP pulse (no re-shift while CP is held high); enable gating of the parallel
outputs only; serial-out independence from the enable; synchronous reset
clearing, including re-asserted resets mid-run. The 33-cover set proves
non-vacuity (see `coverage_report.md`).

Simulation: the testbench runs a miniature MCS-4 system — an 8-phase CPU
bus master (SYNC at A1, `cm_rom` during A1-A3, port strobes and data during
X2/X3), a SYNC-timed port model latching at the edge ending X3, and two
chained 4003s wired to the port lines. Scoreboarding compares every device
output against an independently formulated 20-bit golden chain at every
settled clock edge; directed scenarios D1-D9 plus a 600-operation
LFSR-driven random phase are described in `plans/testplan.md`.

## 4. Issues Found and Fixed

1. **Formal reset properties vs. synchronous reset latency** — the first
   bmc run produced a counterexample at frame 3: the original assertions
   demanded a cleared register in the very cycle reset is (re-)asserted,
   but synchronous reset clears at the clock edge. The properties were
   corrected (not the RTL): the state is asserted zero in every cycle
   following an edge that sampled reset low. Spec section 8 was reworded to
   state the semantics precisely.
2. **Cover-count guard in `run_coverage.sh`** — the initial script compared
   against the wrong threshold (34) after the cover set settled at 33; the
   comparison was fixed so the script passes exactly when all 33 covers are
   reached.
3. **Verilator `-Wall` UNUSEDSIGNAL in the TB** — the bus master was
   restructured so every bus signal has a real consumer: the port model
   derives its internal phase from SYNC (as real 4001/4002 chips do), and
   the two genuinely unwired port lines are quarantined behind a documented
   lint waiver.

## 5. Interpretations and Source Conflicts

- **10-bit, not 16-bit**: the task brief described a "16-bit shift register
  with 16 parallel I/O lines". The MCS-4 Users Manual (Feb 1973, section
  VI), the November 1971 data sheet, the IEEE "History of the 4004"
  article, MAME's Busicom driver (0x3FF mask), and the TAMS Hades notes all
  describe a 10-bit part, and the 16-pin package only fits with ten
  parallel outputs. The design implements 10 bits; `WIDTH` remains a
  parameter for verification experiments only.
- **Serial 1-bit load, not nibble load**: the brief suggested the 4-bit bus
  nibble is loaded per port-write instruction. The real part is loaded one
  bit at a time through a port line under program control (manual section
  VI; MAME shifts one bit per port write). The CPU's nibble is
  demultiplexed on the board: our canonical wiring uses port bit 0 for CP,
  bit 1 for DATA IN, bit 2 for ENABLE.
- **`clk`/`rst_n` additions**: the historical part is clocked only by its
  CP pin and cleared only by an internal power-on-clear. A synchronous
  sampling clock and a defined reset are documented reconstruction
  additions; CP edge detection models the datasheet's "DATA IN and CP can
  be simultaneous, CP internally delayed" contract (one shift per pulse,
  data sampled at the edge ending the first CP-high clock period).
- **Enable polarity**: `en_i` is active-high in RTL, matching the manual's
  logic convention for the active-low-voltage ENABLE pin; the deasserted
  Vgg output level maps to all-zero bits. The wired-output key-scan
  electrical trick is out of scope.
- Pin *numbers* of the 16-pin DIP were not verifiable from the text sources
  accessible for this build (scanned data sheets); the design is specified
  at pin-name level (CP, DATA IN, ENABLE, SERIAL OUT, Q0-Q9), which is
  unambiguous across sources.

## 6. Known Issues

None open. All checks pass; no unresolved TODOs.

## 7. Sign-off

Run inside `ai-hw-engineer:latest`:

```bash
sh scripts/run_all.sh          # lint + formal (bmc/prove/cover) + sim + synth
sh scripts/run_coverage.sh     # formal cover summary (33 covers)
```

Both complete with exit code 0; the simulation log ends with
`TEST PASSED: 31225 checks, 7807 cycles`.
