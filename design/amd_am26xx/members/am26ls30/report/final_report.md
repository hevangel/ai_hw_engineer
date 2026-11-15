# Am26LS30 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26ls30/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26ls30/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26ls30/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26ls30/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26ls30/scripts/run_sim.sh` | PASS — `am26ls30 TEST PASSED (64 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26ls30/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation sweeps data × mode × slew toggling (64 checks) against
  both published function tables with inline exact-`z` assertions, on
  both simulators.
- Formal asserts both mode contracts row-by-row in every state; covers
  reach every function-table row and slew-pin independence.

## Scope and limits

- Zero-delay combinational reconstruction; RS-422/RS-423 electrical
  envelopes, slew figures, three-state times and protection are
  documented in the spec, not modeled.
- Simulation-toolchain note: Verilator resolves tristate z to 0 across
  task-argument copies, so the z checks are inline; recorded in the
  formal plan, not an RTL property.
- No RTL lint waivers required.
