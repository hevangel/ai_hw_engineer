# Am26S11 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26s11/scripts/run_lint.sh` | PASS (TB waivers documented) |
| Formal bmc | `sh design/amd_am26xx/members/am26s11/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26s11/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26s11/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26s11/scripts/run_sim.sh` | PASS — `am26s11 TEST PASSED (35 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26s11/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation: exhaustive 32-combination sweep with pull-up bias
  (enabled rows: B̄ = I non-inverting, Z̄ = !B̄; released rows: bus
  idles high), plus the directed party-line section, on both
  simulators.
- Formal: non-inverting driver contract and release on the driver-role
  ports, receiver contract with harness-driven bus; covers reach every
  truth-table row class.

## Scope and limits

- Bus pins use the documented split driver/receiver port structure;
  the tie, bias and party-line resolution are simulation-directed
  (same toolchain boundary as the am26s10 member).
- Electrical envelope documented, not modeled.
- No RTL lint waivers; the TB waivers are listed in the plan.
