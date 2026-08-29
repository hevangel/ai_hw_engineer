# Test Plan: Intel 4002

## Overview

This document defines the simulation verification strategy for the Intel
4002 reconstruction. The testbench is a direct, self-checking SystemVerilog
bench (no UVM — the `libs/uvm` submodule is intentionally not used in this
worktree), driving the chip exactly the way the repository's verified
`intel_4004` core drives its RAM: real 8-phase instruction cycles with
M1/M2 fetch broadcast, SRC select-code timing, DCL bank decoding, and X2/X3
data phases.

## Verification Goals

- Functional correctness of every 4002 command (WRM, WMP, WR0-WR3, SBM,
  RDM, ADM, RD0-RD3) and of the ignored ROM-side encodings (WRR/WPM/RDR).
- Full address-space sweeps: 4 registers x 16 main characters, 4 registers
  x 4 status characters.
- Bus-protocol compliance against the 4004 timing contract.
- Chip selection: correct chip responds; wrong chip number, wrong variant,
  and wrong bank line never respond.
- Reset behavior (including reset in the middle of operation).
- Corner cases plus a fixed-seed randomized phase for breadth.

## Testbench Architecture

```
tb_intel_4002 (single module, direct testbench)
├── Clock / reset generator
├── Bus master (CPU model)
│     ├── 8-phase task engine (A1..X3, sync pulse, M1/M2 fetch drive)
│     ├── DCL bank decode ({cmd[2],cmd[1],cmd[0],~|cmd}, as the 4004)
│     └── SRC / RAM-command task library
├── Shared 4-bit bus resolution (OE-qualified, tri-state model)
├── DUT 1: intel_4002 #(.Variant1(1)) po=1  -> chip 1, bank 0 (4002-1)
├── DUT 2: intel_4002 #(.Variant1(0)) po=0  -> chip 2, bank 3 (4002-2)
├── Golden model (independently coded arrays + decode)
├── Scoreboard (per-cycle bus checks + end-of-instruction state compares)
└── Check counter / PASS-FAIL reporter
```

Two DUTs on one bus exercise the variant parameter, the chip-number decode,
and bank separation exactly as in a real two-bank system.

## Test Categories

### Directed Tests

| Test | Description | Priority |
|------|-------------|----------|
| reset_behavior | Post-reset state: port = 0, both chips idle, no drive | P1 |
| main_memory_sweep | WRM/RDM across all 4 registers x 16 characters, both banks | P1 |
| status_sweep | WR0-WR3 / RD0-RD3 across all registers, both banks | P1 |
| adm_sbm | ADM and SBM data supply (memory nibble on the bus; CPU-side arithmetic modeled in the TB) | P1 |
| wmp_port | WMP writes, hold between WMPs, overwrite, per-chip port isolation | P1 |
| chip_select | SRC to chips 0/1/2/3: exactly the addressed chip responds | P1 |
| wrong_bank | DCL to the other bank: selected chip must not respond | P1 |
| rom_side_ops | WRR/WPM/RDR opa encodings: no 4002 state change, no drive | P2 |
| reset_mid_op | Reset between commands: port and memory cleared, chip fully functional after | P1 |

### Randomized Tests

| Test | Description | Constraints |
|------|-------------|-------------|
| random_phase | Fixed-seed LFSR stimulus: random commands, chips, banks, registers, characters, data against the golden model, for both DUTs | OPA drawn from the 16 I/O-group encodings; bus master always issues well-formed cycles |

### Error / Negative Tests

| Test | Expected Behavior |
|------|-------------------|
| Read from an unselected chip | Bus undriven (`data_oe` = 0 on both DUTs), TB observes no drive |
| Write while bank line low | Golden model unchanged; subsequent readback proves no write |

## Coverage Plan

### Functional Coverage (from the directed + random phases, reported in
`report/coverage_report.md`)

| Cover point | Target |
|-------------|--------|
| Every command executed and observed selected | 13/13 |
| Main-memory cells written/read (register x character) | 64/64 |
| Status cells written/read (register x status char) | 16/16 |
| Both variants (4002-1 chip 1, 4002-2 chip 2) selected | 2/2 |
| Foreign chip numbers and foreign banks exercised | all |
| WMP overwrite and reset-clear paths | hit |

### Code Coverage Targets

Simulator/Verilator coverage collection is not used; functional coverage
evidence is the per-command/per-cell check matrix in the coverage report.

## Regression Strategy

- `scripts/run_sim.sh` runs the single self-checking bench (directed +
  random in one run) and exits nonzero on any failure.
- `scripts/run_all.sh` chains lint, sim, formal, synthesis.

## Pass/Fail Criteria

- Every scoreboard comparison matches (bus nibble on every read phase,
  golden state at every instruction boundary, `io_o` at every cycle).
- Final line: `TEST PASSED: <n> checks, <m> cycles`.
- No `FAIL` lines in the log; since xezim does not reliably exit nonzero on
  `$display`-based check failures, `run_sim.sh` additionally greps the log
  and exits nonzero unless the pass line is present with zero `FAIL` lines.
