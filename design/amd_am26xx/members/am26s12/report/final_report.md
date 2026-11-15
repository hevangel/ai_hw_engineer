# Am26S12 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26s12/scripts/run_lint.sh` | PASS (TB waivers documented) |
| Formal bmc | `sh design/amd_am26xx/members/am26s12/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26s12/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26s12/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26s12/scripts/run_sim.sh` | PASS — `am26s12 TEST PASSED (67 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26s12/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean at REVISION 0 |

## Evidence detail

- Simulation: exhaustive 64-combination dual-enable sweep with pull-up
  bias (both-enables-low rows drive B̄ = !I; either-enable-high rows
  release the bus to the pull-up; receivers read the resolved bus
  throughout), plus the directed party-line section, on both
  simulators.
- Formal: driver contract with the dual-enable AND, release, receiver
  contract; covers reach every truth-table row class.
- The elaboration-time check pins the documented S12 threshold pair and
  the datasheet's >0.4 V margin guarantee.

## Scope and limits

- The S12/S12A grade difference is analog (receiver hysteresis
  thresholds); the digital contract is identical and the [Am26S12A
  member](../am26s12a/report/final_report.md) verifies the same source
  separately at REVISION 1.
- Bus pins use the documented split driver/receiver port structure;
  the tie, bias and party-line resolution are simulation-directed
  (same toolchain boundary as the am26s10 member).
- Electrical envelope documented, not modeled.
