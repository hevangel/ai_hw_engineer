# Apple IIe PAL — Validation Report

## Result

The complete flow passes: lint, formal (bmc / unbounded prove / non-vacuous
cover), Verilator and xezim simulation against an independent reference
model, code coverage and Yosys synthesis.

| Stage | Result |
| --- | --- |
| `verilator --lint-only -Wall` (RTL, no waivers) | PASS |
| Formal bmc (abc bmc3, depth 32) | PASS |
| Formal prove (abc pdr, unbounded) | PASS |
| Formal cover (smtbmc z3, all covers reached) | PASS |
| Verilator simulation, seed 1 | PASS (43,051 checks) |
| xezim simulation, seed 1 | PASS (43,107 checks) |
| Code coverage (xezim, `tb_top.dut`) | statement 38/38, branch 10/10, toggle 58/58 — all 100% |
| Yosys `synth` + `check -assert` | PASS |

## What was verified

- **Tick structure** (spec 4): the 14-state cycle counter, including the
  13→0 wrap and the hold-at-0 behavior while master timing is disabled.
- **CPU clocks** (Table 7-5, Figure 7-1): φ0 high ticks 0-6 / φ1
  complement; Q3 = 4-high/3-low over a 7-tick period — exactly the TRM's
  280 ns + 210 ns = 490 ns decomposition — with falls at ticks 4 and 11.
- **DRAM strobes** (Tables 7-8/7-10): PRAS' high ticks 0-3 (row setup) and
  falling coincident with Q3 at tick 4 (the row→column transition
  convention shared with the MMU/IOU designs); PCAS' falling at tick 6
  (column address stable ≥ 2 ticks), high at 13 and through tick 0.
- **CAS gating**: with RAMEN' inactive (sampled entering tick 5, A7), PCAS'
  stays high through ticks 6-12 — the "RAM enable (CAS enable)" behavior
  that suppresses CAS on non-RAM (ROM/I-O) cycles, matching the MMU
  design's CASEN' pin contract. PRAS' continues every cycle (refresh, A3).
- **LDPS' cadence** (TRM ch. 2/ch. 7): one pulse per cycle in 40-column;
  two pulses per cycle (ticks 6 and 13 — once per clock phase) in
  80-column. Pulse *positions* are reconstruction choices (A4).
- **VID7M**: tracks the 7M input delayed one tick (7 MHz dot-clock rate,
  Tables 7-5/7-8) — with the mode-dependent gating explicitly out of scope
  (A5).
- **ENTMG hold** (A6): all outputs at the idle pattern and the counter
  parked at 0 while master timing is disabled; verified through random
  drop/re-raise sequences.

## Verification style

The testbench reference model is an independent encoding of the spec: an
explicit 14-entry truth table per output (the RTL uses arithmetic compares
on the next-tick decode). Formal properties restate the spec with
independent encodings (e.g., a subtract-based mod-7 for Q3). The soak runs
6,000+ randomized ticks with random RAMEN'/80VID'/7M patterns and random
ENTMG drops.

Bugs the flow caught during bring-up (all in the *harness/golden* side,
illustrating the independent-encoding discipline): an inverted CAS-gate
assertion and an input-sample skew in the LDPS' property (formal BMC), a
one-tick-late RAMEN' sample in the model, and a lost model increment across
ENTMG re-enable (simulation).

## Known limitations

See the assumption ledger A1-A8 in [spec/spec.md](spec/spec.md): NTSC-only;
LDPS' pulse positions are reconstruction choices; the PAL's mode-dependent
VID7M/LDPS' gating (Sather's SEGB/GR/VID7/80COL' equations) is not
reconstructed — no citable public source for the fuse equations; ENTMG
modeled as a synchronous hold (the real pin 11 is the PAL16R8 output
enable); the 3.58M/H0/VID7/SEGB/GR pins are documented but not ports.
