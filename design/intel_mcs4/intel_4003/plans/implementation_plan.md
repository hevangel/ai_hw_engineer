# Implementation Plan: Intel 4003

## Goal

A synthesizable, synchronous functional reconstruction of the 10-bit
serial-in/parallel-out/serial-out shift register I/O expander of the MCS-4
set, matching `spec/spec.md` and integrating cleanly with this repository's
`intel_4004` bus conventions.

## Deliverables

| Item | Path |
|------|------|
| RTL core | `src/intel_4003.sv` (module `intel_4003`, parameter `WIDTH = 10`) |
| Formal harness | `formal/intel_4003.sby`, `formal/intel_4003_props.sv`, `formal/intel_4003_cover.sv` |
| Testbench | `tb/tb_intel_4003.sv` (direct, self-checking, no UVM) |
| Scripts | `scripts/run_sim.sh`, `scripts/run_formal.sh`, `scripts/run_synth.sh`, `scripts/run_coverage.sh`, `scripts/run_all.sh` |
| Reports | `report/final_report.md`, `report/coverage_report.md` |

A package file is not needed: the design is a single module with no shared
types.

## RTL Design

### State

- `sr` : 10-bit shift register, `sr[0]` nearest DATA IN.
- `cp_prev` : previous-cycle sample of CP for synchronous edge detection.

### Combinational logic

- `shift_pulse = cp_i && !cp_prev` — one shift request per CP pulse.
- `sr_next = shift_pulse ? {sr[8:0], data_in_i} : sr` — computed as a single
  unconditional next-value (never default-then-override; this keeps exactly
  one write per state element per clock, which the xezim simulator requires).
- `q_o = en_i ? sr : '0`.
- `so_o = sr[9]` (enable-independent).

### Sequential logic

One `always_ff` block: on reset (`rst_n` low, synchronous) clear `sr` and
`cp_prev`; otherwise commit `sr_next` and `cp_prev <= cp_i`.

### Coding rules

- IEEE 1800-2017, `logic` everywhere, `always_ff`/`always_comb` only.
- Every literal explicitly sized (Verilator `-Wall` cleanliness).
- Inline `` `ifdef FORMAL `` block with immediate assertions only (Yosys
  rejects concurrent SVA), instantiating `intel_4003_props` (bmc/prove) or
  `intel_4003_cover` (cover) exactly like the `intel_4004` core does.
- Unused-parameter hygiene: `WIDTH` is used throughout; no dead code.

## Verification Mapping

- Formal: shadow-model equivalence plus `$past`-based shift/hold semantics,
  enable/serial-out rules, reset rules; 33 covers for non-vacuity (see
  `formal_plan.md`).
- Simulation: a behavioral MCS-4 CPU-side bus master issues real 8-phase
  port-write cycles (sync, cm_rom/cm_ram timing, data during X2/X3, port
  latch at end of X3) per the `intel_4004` spec section 6; two chained 4003
  instances are wired to the port bits (CP/DATA IN/ENABLE) and scored against
  an independently formulated 20-bit golden chain every cycle (see
  `testplan.md`).

## Milestones

1. Spec finalized from primary sources (done; see spec section 12 for the
   researched deviations from the task brief).
2. RTL + lint clean under `verilator --lint-only -Wall`.
3. Formal bmc/prove/cover all PASS.
4. Simulation directed + random phases PASS with scoreboard counts.
5. Yosys generic synthesis clean; cell count recorded.
6. Reports, READMEs, design-index row, session history; commit and PR.
