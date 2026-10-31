# Test Plan: intel_4001

## Overview

Simulation strategy for `tb/tb_intel_4001.sv`, a direct (non-UVM)
self-checking testbench run on xezim via `scripts/run_sim.sh`. The bench
models a small MCS-4 bus: the testbench itself plays the 4004 CPU
(a behavioral bus master issuing genuine 8-phase instruction cycles with
the exact timing of the verified `intel_4004` reconstruction), and one or
two `intel_4001` DUT instances sit on the shared bus with different chip
numbers and masks. An independently written golden model predicts every
bus period and every state change; scoreboarding compares at every clock.

## Testbench Architecture

- **Clock/reset**: 10 ns period clock generated in an `initial` block;
  active-low reset held 4 cycles at start (and pulsed mid-run for reset
  tests), matching repository conventions.
- **Bus master tasks** (one per operation, each one or more 8-phase cycles;
  the single primitive is `do_cycle(inject, w_hi, w_lo, a3, x2_cm, x2_en,
  x2_val, x3_cm, x3_en, x3_val)`, which issues one full A1-X3 period
  sequence with the CPU driving the A1/A2/A3 address nibbles, injecting the
  fetched word at M1/M2 when no ROM chip is addressed, and driving or
  releasing the bus at X2/X3):
  - `op_fetch(chip, a)` — real-ROM fetch: address nibbles at A1/A2, chip
    number at A3, bus released at M1/M2 for the addressed chip to drive the
    word.
  - `op_idle(word)` — injected-word cycle aimed at absent chip 2 (NOP,
    WPM-encoded, and other non-participating opcodes).
  - `op_wpm_active(data)` — WPM with active X2/X3 drive and CM-ROM, the
    pattern the 4004 drives.
  - `op_src(sel_hi, sel_lo)` — SRC: pair-high nibble at X2, pair-low at
    X3 (ignored by the chip), no CM-ROM at the X periods.
  - `op_wrr(sel_hi, data)` — `op_src` + WRR cycle with the data nibble
    driven at X2 and X3.
  - `op_rdr(sel_hi)` — `op_src` + RDR cycle with the bus released at
    X2/X3 for the selected chip.
  - `op_clr` — a full NOP cycle with CL asserted throughout.
  - `reset_mid_cycle(p)` — a partial cycle cut off by a 3-period reset at
    period p, then realigned on the next SYNC'd A1.
- **Golden model**: an independent behavioral record (latched address,
  selection flags, select register, port latch, expected `data_oe` /
  `data_o` per period, expected `port_o`) updated inside the checker, not
  from DUT internals. Compared every clock period; DUT internal state
  (`addr_q`, `opr_q`, `opa_q`, `io_sel_q`, `port_q`, `phase`) compared at
  every cycle boundary via hierarchical reference.
- **Two DUT instances** share the bus: chip 0 (default mask, all-output
  I/O) and chip 1 (secondary mask, mixed direction I/O). A bus resolver
  ORs the oe-gated `data_o` values and feeds the result to `data_i`,
  exactly as a wired-OR bus behaves; the golden model checks that at most
  one instance drives and that non-driven periods show `data_oe` = 0.

## Directed Tests

| # | Test | Checks |
|---|------|--------|
| D1 | Reset behavior | After reset: `data_oe`=0, phase counters at A1, port latch survives `rst_n`, cleared by `clr_n`; `port_oe` == `IO_DIR` |
| D2 | Exhaustive ROM read, chip 0 | All 256 addresses, both nibbles vs the mask function; includes 0x00 and 0xFF |
| D3 | Exhaustive ROM read, chip 1 | All 256 addresses vs the second mask; proves contents independence |
| D4 | Chip select/deselect | Interleaved fetches to chips 0/1/2 (2 absent): unselected chip never drives; correct data from selected |
| D5 | WRR/RDR basic | SRC chip 0; WRR value; RDR returns it; `port_o` reflects latch |
| D6 | WRR overwrite | Second WRR with different value; RDR returns newest |
| D7 | Per-chip port isolation | SRC chip 1, WRR/RDR its value; chip 0 latch unchanged |
| D8 | Mixed IO_DIR | Chip 1 has 2 output + 2 input pins; RDR returns latch for output bits and `port_i` for input bits; both all-0 and all-1 pin values |
| D9 | Unselected port ops | SRC chip 2 (absent): WRR leaves both latches; RDR drives nothing (`data_oe`=0) |
| D10 | No-SRC default select | After reset with chip 0: WRR/RDR work without SRC (select register resets to 0) |
| D11 | X3-ignored rule | SRC whose X3 nibble equals a real chip number must not change the selection made at X2 |
| D12 | Ignored instructions | NOP/WPM/WRM-style fetches between port ops leave select register and latch untouched |
| D13 | Reset mid-operation | Assert `rst_n` during M2 of a fetch and during X2 of a WRR: bus released next period, state cleared, port latch preserved; system resumes correctly |
| D14 | clr mid-operation | `clr_n` pulse after WRR: latch 0 while everything else keeps running |
| D15 | CL vs WRR same edge | `clr_n` low through a complete WRR cycle: the clear dominates the simultaneous X3 write on both chips; RDR afterwards returns 0 |

The SYNC re-lock rule (a chip treating any `sync` period as A1, so master
and chip counters re-align even after misaligned resets) is exercised
structurally: every reset test re-enters normal traffic through a SYNC'd
A1, and the phase counters of both DUTs are compared against the master's
period counter at every clock.

## Randomized Phase

A fixed-seed 16-bit LFSR generates 1,500 random operations: random chip
number (0-3, of which 2 and 3 are absent), random 8-bit ROM address,
random SRC select, random WRR/RDR data and `port_i` values, and randomly
interleaved fetches, injected no-ops, active WPM cycles, and full-CL
clear cycles. The golden model checks every bus period and latch. The
fixed seed keeps the run reproducible; the final line of the log reports
the total check and cycle counts.

## Coverage

Functional coverage is by enumeration in the directed list above: all 256
ROM addresses x 2 chips; SRC select targets 0, 1, and 2 (present and
absent) directed, 0-3 in the random phase; WRR data 0x0/0x3/0x5/0xA/0xC/
0xD/0xF directed plus the full 0-F range reached randomly; both RDR value
sources (latch bits and pin bits); reset from power-on, mid-fetch, and
mid-WRR; CL from mid-run pulses and CL-through-WRR.
`report/coverage_report.md` records the achieved enumerations.

## Pass Criteria and Exit Status

The final line of the log is `TEST PASSED: <n> checks, <m> cycles` with
n the scoreboard check count and m the elapsed clock count. Any mismatch,
unexpected drive, or golden-model divergence prints
`FAIL: <description>`, increments the failure count, and the final line
becomes `TEST FAILED: <k> failures`. `scripts/run_sim.sh` greps the log
for `TEST PASSED` (and absence of `FAIL`) and exits nonzero on failure,
because simulators may exit 0 even when the bench reports errors.
