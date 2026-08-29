# Test Plan: Intel 4003

## Overview

Direct, self-checking simulation (no UVM) of two chained `intel_4003`
instances driven exactly as they would be in an MCS-4 system: a behavioral
CPU-side bus master issues genuine 8-phase port-write instruction cycles,
an on-board port model latches the nibble at the edge ending X3 (per the
`intel_4004` spec section 6.3), and the port bits wire to CP / DATA IN /
ENABLE of the 4003 chain (spec section 3.3). An independently formulated
20-bit golden shift chain is compared against both devices every cycle.

## Environment

- `tb/tb_intel_4003.sv`, top module `tb_intel_4003`, clock period 10 ns
  generated in an `initial` block (one `clk` = one MCS-4 clock period,
  matching the 4004 convention).
- CPU master tasks:
  - `port_write(nibble, is_rom_port)` — one full instruction cycle: SYNC at
    A1, `cm_rom` A1-A3, WRR/WMP-style `cm_rom`/`cm_ram` during X2-X3 with
    the nibble driven on the bus; the port latch updates at the edge ending
    X3.
  - `idle_cycle()` — a no-op instruction cycle (valid fetch timing, no port
    change).
- Wiring under test (port 0, ROM port): bit 0 -> CP (both DUTs), bit 1 ->
  DATA IN of DUT1, bit 2 -> ENABLE (both DUTs); DUT1 SERIAL OUT -> DUT2
  DATA IN.
- Golden model: a 20-bit register shifted as `(chain << 1) | data_bit` on
  each detected CP pulse — formulated differently from the RTL (single
  vector, arithmetic shift) to keep the reference independent.
- Scoreboard: at every negedge (all values settled) compare DUT1
  `q_o`/`so_o` and DUT2 `q_o`/`so_o` against the golden chain with ENABLE
  gating applied; every compared signal counts as one check. Directed
  scenarios add explicit counted assertions.
- Failure policy: every mismatch increments `failure_count` and prints a
  `FAIL` line; the run prints `TEST PASSED: <n> checks, <m> cycles` only if
  no failures occurred, otherwise `TEST FAILED: <k> failures`. Watchdog
  timeout also fails. `scripts/run_sim.sh` greps the log for the pass line
  and exits nonzero otherwise (in addition to xezim `--error-exit`).

## Directed Tests

| ID | Scenario | Checks |
|----|----------|--------|
| D1 | Post-reset state with ENABLE on | q/so zero after reset release before any CP pulse |
| D2 | Full 10-pulse loads, MSB-first: 0x000, 0x3FF, 0x155, 0x2AA, 0x2E5, plus several pseudo-random words | parallel word equals the sent word after exactly 10 pulses; serial-out tracks during the load |
| D3 | Partial load (4 pulses) | new bits in stages 0-3, old content preserved in stages 4-9 |
| D4 | CP held high across multiple instruction cycles (port latch keeps the line up) | exactly one shift, register stable while CP idles high |
| D5 | DATA IN and CP set in the same port write | simultaneous-change capture (spec 6.3) |
| D6 | Cascade: 20-bit word streamed through DUT1 into DUT2; intermediate check after 10 pulses | both 10-bit halves correct; transit states correct |
| D7 | Reset mid-load (5 pulses, then reset, then reload) | register clears despite mid-pulse reset; fresh load unaffected |
| D8 | ENABLE gating: shift pulses while disabled, then re-enable | outputs masked while disabled; register still advanced; serial-out live throughout |
| D9 | Bit-order mirror: LSB-first send | parallel word is the bit-reversal of the stream |
| R1 | Randomized phase: 600 LFSR-driven port writes with random enable flips, random idle cycles (0-3), random data/CP patterns | continuous per-cycle scoreboard; zero mismatches |

## Coverage Expectations

- D1-D9 exercise every row of the shift-summary table (spec 6.6), both
  enable states, both bit orders, cascade and reset.
- Formal covers (33) prove reachability independently; see
  `report/coverage_report.md`.

## Exit Criteria

- `verilator --lint-only -Wall` clean for RTL and TB.
- sby bmc/prove/cover PASS.
- `TEST PASSED: <n> checks, <m> cycles` with zero failures.
- Yosys synthesis completes without error.
