# Am2615 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2615/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2615/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am2615/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am2615/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am2615/scripts/run_sim.sh` | PASS — `am2615 TEST PASSED (64 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2615/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exhaustively checks all 64 input combinations against the
  per-receiver OUT = !(COMP && STROBE) contract with the fail-safe tie
  resolution on both simulators.
- Formal asserts the contract, strobe-idle, fail-safe and differential-
  state properties in every state and reaches every documented behavior
  cover.

## Scope and limits

- Zero-delay combinational reconstruction; the analog comparator
  (threshold −1.5 V, common-mode range, response control), the active
  pull-up output structure and the 130 Ω terminations are documented,
  not modeled.
- Source conflict (loading-rules table pin-label swap) resolved from
  three agreeing figures; recorded in the spec, not an RTL waiver.
