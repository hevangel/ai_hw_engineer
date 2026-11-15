# Am26LS31 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26ls31/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26ls31/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26ls31/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26ls31/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26ls31/scripts/run_sim.sh` | PASS — `am26ls31 TEST PASSED (64 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26ls31/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exhaustively checks all 64 input combinations with
  bit-wise `===` assertions distinguishing driven values from the `z`
  state, on both simulators.
- Formal asserts the driven contract and enable semantics in every
  state; covers reach the enable-pair corners, differential states,
  the disabled state, and a mixed data pattern.

## Scope and limits

- Zero-delay combinational reconstruction; RS-422 conformance, output
  skew, delays, terminated-line drive and short-circuit protection are
  documented in the spec, not modeled.
- No RTL lint waivers required.
