# Final Design Report: Intel 4002

## 1. Executive Summary

The Intel 4002 — the 320-bit RAM and 4-bit output-port chip of the MCS-4
family (announced with the set on November 15, 1971) — is implemented as a
single-clock synthesizable functional reconstruction whose bus protocol is
drop-in compatible with this repository's verified `intel_4004` core. All
nine 4002 operations (WRM, WMP, WR0-WR3, SBM, RDM, ADM, RD0-RD3) are
complete, including SRC select-code latching, 4002-1/4002-2 variant decode
with the P0 strap, DCL bank-line gating, and the ignored ROM-side encodings
(WRR/WPM/RDR).

Strict lint passes without warnings. A 1,048-cycle xezim regression
scoreboards every valid bus cycle and both output ports against an
independently written golden model with zero mismatches (22,297 checks),
sweeping all 64 main-memory cells and all 16 status characters on both
modeled chips and finishing with a fixed-seed random phase. Formal
verification proves the full protocol transition function for arbitrary bus
traffic (bounded and unbounded) against a second independent golden model,
plus 37/37 reachability covers. Yosys generic synthesis reports zero
problems and 1,614 cells.

## 2. Design Overview

- Module: `intel_4002`
- Version: 1.0
- Validation date: 2026-08-28
- Language: SystemVerilog IEEE 1800-2017
- Storage: 64 x 4-bit main memory + 16 x 4-bit status characters + 4-bit
  output-port latch (320 architectural bits)
- Bus: 4-bit multiplexed data bus as separate `data_i`/`data_o`/`data_oe`
- Command lines: `sync`, per-bank `cm_ram_i`, `po_i` chip-number strap
- Parameters: `Variant1` (4002-1 answers chip numbers 0/1, 4002-2 answers
  2/3)
- Clock/reset: single `clk` (one clock per historical clock period) with a
  synchronous active-low `rst_n` (reconstruction additions; the historical
  part runs two non-overlapping clock phases, an asynchronous RESET with a
  32-instruction-cycle array-clear sweep, and a dynamic array with refresh —
  see spec sections 9 and 11)

The phase counter restarts on every SYNC pulse so phase 0 always coincides
with A1, mirroring the verified 4004. Commands are learned by listening to
the instruction word at M1/M2 (as the historical 4002s receive their OPA);
SRC loads the address register at X2/X3 on an active bank line; writes
commit at the edge ending X3; reads drive during X2/X3 — exactly the 4004
core's contract, so a future full-system integration needs no glue logic.

## 3. Reproducible Toolchain

| Tool | Validated version |
|---|---|
| Verilator | 5.050 |
| xezim | image default (0.10.x) |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | v0.68 |
| Z3 | 4.8.12 |
| ABC | image default |

All validation ran in Docker image `ai-hw-engineer:latest`, with the
worktree root mounted at `/workspace` and scripts invoked as
`bash design/intel_4002/scripts/run_<x>.sh`.

## 4. Verification Results

### 4.1 Lint

| Check | Result |
|---|---|
| RTL: `verilator --lint-only -Wall --top-module intel_4002 src/intel_4002.sv` | PASS, zero warnings |
| TB + RTL: `verilator --lint-only -Wall --timing --top-module tb_intel_4002 -Isrc src/intel_4002.sv tb/tb_intel_4002.sv` | PASS, zero warnings |

### 4.2 Simulation (`tb/tb_intel_4002.sv`)

`TEST PASSED: 22297 checks, 1048 cycles` — zero failures. Two DUTs share one
tri-state-resolved bus (4002-1 chip 1 on bank 0; 4002-2 chip 2 on bank 3).
The golden model is checked continuously (`io_o` of both chips every phase)
and per X2/X3 window (expected bus nibble on reads, undriven bus otherwise,
OE mutual exclusion). Directed phases: post-reset state, WRM/RDM sweep of
all 4 registers x 16 characters on both banks, WR0-WR3/RD0-RD3 status sweep,
ADM/SBM nibble supply with a TB-side CPU-arithmetic sanity check, WMP
write/overwrite/clear with per-chip port isolation, chip-number select/
deselect for chips 0-3, wrong-bank-line deselect, ROM-side opcode ignore,
reset mid-operation. A 400-cycle fixed-seed LFSR phase randomizes DCL/SRC/
commands/data against the golden model.

### 4.3 Formal (`formal/intel_4002.sby`, tasks bmc/prove/cover)

| Task | Engine | Depth | Result |
|---|---|---|---|
| bmc | abc bmc3 | 30 frames | PASS, 114 s ("No output asserted in 30 frames") |
| prove | abc pdr | unbounded | PASS, 56 s |
| cover | smtbmc --unroll z3 | 30 | PASS, 91 s, 37/37 covers reached, 0 unreached |

Environment assumptions (both property modules): reset asserted for the
first two edges, then `sync` high exactly once every 8 clocks; `data_i`,
`cm_ram_i`, and `po_i` remain completely free, so every safety property is
proven for every possible instruction stream, bank activity, and strap.

Property groups (`formal/intel_4002_props.sv`): S1 full-state equality
against an independent golden model (phase counter, OPR/OPA latches, address
register, output port, and both complete arrays as flat vectors) at every
clock; S2 write-read consistency at `anyconst` main and status cells; S3 no
cross-address corruption (separate `anyconst` pairs for main and status);
S4 drive-enable gating (`data_oe` implies X2/X3, read command, active bank
line, matching chip number, and exactly the golden selected nibble; never
drives with the bank line low); S5 output-port semantics via expectation
tracking; S6 reset clears all state one cycle after the reset edge; S7 SRC
nibble placement at X2/X3.

Reachability covers (`formal/intel_4002_cover.sv`, 37 statements): every
command executing selected (13), nonzero read data for SBM/RDM/ADM (3),
write-read roundtrips matching the tracked cell for main and status (2),
WMP overwrite with a different value (1), SRC field extremes (4), selection
corners (3), drive-enable placement (3), unselected-read no-drive (1),
ROM-side idle (1), reset paths (2), sequencer wrap and SRC-then-command
(2), status-write register 2 and main-write character 15 (2).

Cover-engine note: the cover task is the one mode SymbiYosys cannot run
with ABC, and z3 does not converge on this design's SMT-array encoding —
the first cover build stalled for hours at steps 7-9. The committed fix
(`memory_map` + `opt -fast` on the cover task's Yosys script, and a cover
module that no longer re-reads the array through the 64-way `main_flat` mux)
brings the full cover run to PASS in about 90 seconds; the bmc/prove tasks
keep their untouched ABC flow. The abandoned approaches are recorded in
`plans/formal_plan.md`.

### 4.4 Synthesis (`scripts/run_synth.sh generic`, Yosys 0.46)

Zero errors; no latches, no processes, no memories remaining (the arrays
map to flip-flops, per spec Section 8).

```
Number of cells:               1614
  $_AND_                        231
  $_DFFE_PP_                    320
  $_MUX_                        656
  $_NOT_                         32
  $_OR_                         132
  $_SDFFE_PN0P_                  20
  $_SDFF_PN0_                     1
  $_SDFF_PP0_                     2
  $_XOR_                        220
```

343 sequential cells (320 array bits with write-enable, 23 control/state
bits with synchronous reset), 1,271 combinational cells.

## 5. Engineering Record (inherited work and changes)

The design was completed in two sessions. The first session produced the
specification, RTL, properties, cover set, testbench, scripts, and plans,
and proved bmc/prove green, but was interrupted with the cover task
non-convergent (hours-long z3 stalls) and without reports, README, index
entry, or commit. The second session changed no RTL: it diagnosed and fixed
the cover bottleneck (Section 4.3), re-ran the full verification suite from
scratch, and completed the documentation. Files changed by the second
session: `formal/intel_4002.sby` (cover task script only),
`formal/intel_4002_cover.sv` (reset-cover simplification, unused-port fold),
`plans/formal_plan.md` (actual strategy + engineering record),
`plans/testplan.md` (pass/fail wording), `README.md`, both reports, the
design index row, and the session history.

Interpretations of the historical sources (read-drive phase vs MAME, write
commit edge, address-load vs response gating, static array, synchronous
reset) are documented in spec Section 9 with their references; no source
conflict was found that the spec does not already record.

## 6. Known Issues

| Issue | Severity | Impact | Workaround |
|---|---|---|---|
| None open | — | — | — |

Note (tooling, not design): on Windows hosts, deleting `work/formal/*_console.log`
while a killed container still holds the file leaves the name in a
pending-delete state, after which inside-container creates of that exact
name fail with ENOENT. Recreating the file from the host clears it.

## 7. Sign-off

| Criterion | Status |
|---|---|
| RTL lint clean (Verilator -Wall) | PASS |
| Formal bmc/prove/cover | PASS / PASS / PASS (37/37 covers) |
| Simulation | PASS, 22,297 checks, 1,048 cycles |
| Synthesis (Yosys generic) | PASS, 1,614 cells |
| Documentation (spec, plans, README, index) | Complete |
