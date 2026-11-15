# Am26S12A verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26s12a/scripts/run_lint.sh` | PASS at REVISION 1 (TB waivers documented) |
| Formal bmc | `sh design/amd_am26xx/members/am26s12a/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26s12a/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26s12a/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26s12a/scripts/run_sim.sh` | PASS — `am26s12a TEST PASSED (67 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26s12a/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean at REVISION 1 |

## Evidence detail

- The shared [am26s12 source](../am26s12/src/am26s12.sv) is verified
  separately at REVISION 1 per the parent issue's revision rule: the
  exhaustive dual-enable sweep, released-bus bias checks and party-line
  sequence run against the S12A-parameterized instance on both
  simulators, and the formal properties are proven on the same
  instance.
- The elaboration-time check pins the documented S12A threshold pair
  (2.25/1.2 V typ) and the datasheet's >0.4 V margin guarantee.

## Scope and limits

- The grade difference is analog (receiver hysteresis thresholds); the
  digital contract is identical across grades and both grades are
  verified separately (this member at REVISION 1, [Am26S12
  member](../am26s12/report/final_report.md) at REVISION 0).
- Bus pins use the documented split driver/receiver port structure;
  the tie, bias and party-line resolution are simulation-directed.
- Electrical envelope documented, not modeled.
