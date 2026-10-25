# Implementation Plan: Intel 4002

## Overview

Reconstruct the Intel 4002 — the 320-bit RAM and 4-bit output-port chip of
the MCS-4 family — as a synchronous, synthesizable SystemVerilog model whose
bus protocol interoperates directly with the repository's verified
`intel_4004` core. The behavioral contract is `spec/spec.md`; historical
sourcing is summarized there.

## Architecture

A single module with four functional blocks, mirroring the block diagram in
the MCS-4 manual's 4002 chapter:

1. **Phase sequencer** — 3-bit counter resynchronized by `sync`, tracking
   the 8-period instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3).
2. **Command decode** — OPR/OPA latches loaded by listening to the shared
   bus at M1/M2; decodes the nine 4002 operations (WRM, WMP, WR0-WR3,
   SBM, RDM, ADM, RD0-RD3) and ignores the ROM-side encodings.
3. **Address register + chip selection** — SRC loads {chip, register} at X2
   and {character} at X3 when the bank line is active; response additionally
   requires the chip number (from `Variant1` and `po_i`) to match.
4. **Storage** — 64 x 4-bit main-memory array (indexed {register, character}),
   16 x 4-bit status array (indexed {register, status-char}), 4-bit output
   port latch.

## Module Hierarchy

```
intel_4002 (single module, one file)
├── phase counter + sync resync
├── M1/M2 command latches and decode
├── X2/X3 address-register load + chip-number compare
└── main/status arrays + output port, single commit block
```

`ifdef FORMAL` adds a flattened view of the arrays plus instantiation of
`formal/intel_4002_props.sv` (bmc/prove) or `formal/intel_4002_cover.sv`
(cover task, `FORMAL_COVER` defined).

## Implementation Phases

### Phase 1: RTL
- [x] Port list per spec Section 3 (bus split into data_i/data_o/data_oe)
- [x] Phase sequencer with sync resynchronization
- [x] Command decode and address/chip-select logic
- [x] Main memory, status characters, output port with single-writer commit
- [x] Synchronous reset clearing all state (spec Section 7)
- [x] Verilator `--lint-only -Wall` clean

### Phase 2: Formal
- [x] `formal/intel_4002.sby` with bmc/prove/cover tasks
- [x] Independent golden model in `intel_4002_props.sv`; full-state equality
- [x] Explicit properties: write-read consistency, no cross-address
      corruption, drive-enable gating, output-port semantics, reset
      behavior, SRC address decode
- [x] Cover enumeration of every command and corner (>= 30 covers, all pass)

### Phase 3: Simulation
- [x] `tb/tb_intel_4002.sv`: direct self-checking testbench (no UVM) with a
      bus master reproducing the verified 4004's 8-phase timing, two DUT
      instances (4002-1 chip 1 and 4002-2 chip 2), golden scoreboards
- [x] Directed tests: every command, all registers x characters, chip
      select/deselect, wrong bank line, WMP overwrite, reset mid-operation
- [x] Randomized phase against the golden model (fixed seed)
- [x] `scripts/run_sim.sh` exits nonzero on failure

### Phase 4: Sign-off
- [x] Yosys synthesis clean; cell count recorded
- [x] `report/final_report.md` and `report/coverage_report.md`
- [x] Chip `README.md`, design index row, session history

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Clock scheme | Single clock, one edge per historical clock period | Repository convention (matches `intel_4004`) |
| Reset | Synchronous active-low | Repository convention; historical async RESET noted in spec 9.6 |
| Command decode | Bus listening at M1/M2, ungated | Required for interoperability with the repository 4004 (its `cm_ram` runs X2-X3 only); historically how the 4002 gets the OPA |
| Storage indexing | Flat arrays indexed {register, field} | Avoids multi-dimensional unpacked arrays across the three toolchains |
| Formal properties | Immediate assertions in clocked blocks | Yosys rejects concurrent SVA |

## Constraints

- Synthesizable RTL only: no delays, no initial-block state in RTL.
- Cell count: the full 320-bit array is mapped to flip-flops (no block RAM
  inference required); the exact Yosys generic cell count is recorded in
  the final report.
- Performance: one bus operation per 8-clock instruction cycle.

## Dependencies

- None for RTL. Verification references the branch `design/add-intel-4004`
  (read-only) as the protocol cross-check, and the Docker image
  `ai-hw-engineer:latest` (xezim, Verilator 5.050, Yosys 0.46, SBY v0.68).

## Schedule

| Milestone | Status |
|-----------|--------|
| Spec sourced and written | Done |
| RTL complete, lint clean | Done |
| Formal bmc/prove/cover green | Done |
| Simulation green (directed + random) | Done |
| Synthesis clean, reports written | Done |
