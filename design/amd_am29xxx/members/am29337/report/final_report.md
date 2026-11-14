# Am29337 verification report

Verified digital contract: two 16-bit limit registers with active-low
load enables, signed/unsigned comparators, the exact Table 1 carry
semantics (carry upgrades < to ≤) and Table 2 region behavior
(OOB = ¬(COL·COU), including the impossible-combination row).

## Reproducible results

Toolchain ai-hw-engineer:latest: Verilator 5.052, Yosys 0.69,
SymbiYosys/Z3/ABC. Run `sh design/amd_am29xxx/members/am29337/scripts/run_all.sh`.

- Verilator `--lint-only -Wall`: clean, no suppressions.
- Simulation: 31,032 lockstep comparisons (93,096 checks): directed
  region sweeps around explicitly loaded windows for both windows and
  both SIGNED polarities (boundary values, boundary±1, sign-extreme
  values) × all enable/edge combinations × all four carry pairs, plus
  30,000 random full-space comparisons with interleaved limit reloads.
  Limit loads are driven through the D bus so the model and DUT stay in
  lockstep.
- Formal: BMC depth 16 (smtbmc z3) PASS, unbounded ABC PDR (prove)
  PASS, cover PASS — every Table 2 region row covered for both
  polarities, boundary equalities (D = L, D = U), simultaneous limit
  loads and asymmetric carries; independently recomputed comparisons
  and register capture discipline.
- Synthesis: 216 cells, `check -assert` clean.

## Limits

The prose/Table 2 OOB contradiction is resolved in favor of Table 2
(ledger). Board-level cascade wiring is Figure 1, not device behavior;
only per-slice behavior is verified. Electrical timing is outside the
contract. First-documented date: June 1987 datasheet issue; no exact
first-shipment date asserted.
