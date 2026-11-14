# Am2617 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2617/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2617/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am2617/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am2617/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am2617/scripts/run_sim.sh` | PASS — `am2617 TEST PASSED (16 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2617/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exhaustively checks all 16 input combinations against the
  per-receiver inversion contract on both simulators.
- Formal asserts the inversion contract in every state and reaches
  every documented state-class cover.

## Scope and limits

- Zero-delay combinational reconstruction; the hysteresis window,
  threshold levels, response-control bias, internal pull-up and ±30 V
  input range are documented in the spec, not modeled.
- No RTL lint waivers required.
