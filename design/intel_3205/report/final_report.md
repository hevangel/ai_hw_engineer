# Intel 3205 validation report

Date: 2026-10-08
Environment: `ai-hw-engineer:latest` (Verilator 5.053, Yosys 0.68+195,
SBY v0.69 snapshot, xezim 0.10.5, z3 5.1.0)

## Results

| Step | Result | Evidence |
|------|--------|----------|
| Verilator lint (RTL, `-Wall`, no waivers) | PASS | `run_lint.sh` clean |
| Verilator lint (TB, waived BLKSEQ/PROCASSINIT/UNUSEDSIGNAL) | PASS | `run_lint.sh` clean |
| Formal bmc (smtbmc z3, depth 2) | PASS | `work/formal/bmc/PASS` |
| Formal prove (smtbmc z3, depth 2) | PASS | `work/formal/prove/PASS` |
| Formal cover | PASS, non-vacuous | all nine cover points reached (8 decoded outputs + disabled), trace files in `work/formal/cover/` |
| Verilator simulation | PASS | `intel_3205 TEST PASSED (128 checks)` (64 exhaustive + 64 cascade) |
| Xezim simulation | PASS | `intel_3205 TEST PASSED (128 checks)` |
| Code coverage (xezim) | 100% | statement 2/2, branch 2/2, toggle 18/18 |
| Yosys generic synthesis | PASS | `check -assert` clean, `work/synth/synth.log` |

## What was verified

- Every one of the 64 enable/address input combinations matches the
  datasheet truth table: with E̅1=E̅2=0 and E3=1 exactly output `a` is low;
  otherwise all outputs are high (`tb/tb_top.sv`, exhaustive task).
- The two-level expansion network from the datasheet (one decoder driving
  eight leaf decoders through their active-low enables) behaves as a flat
  one-of-64 active-low decode for all 64 addresses.
- Formal assertions S1-S3 of `plans/formal_plan.md` hold for the full
  unconstrained input space (per-output loop formulation independent of
  the RTL shift decode; `$onehot` mutual exclusion; disabled all-high).

## Known limitations

- Electrical characteristics (18 ns delay, input clamps, drive currents)
  are out of scope for this functional reconstruction.
- The physical 16-pin interface is documented in `README.md` but not
  modeled as pins.
