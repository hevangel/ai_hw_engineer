# Am26S10 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26s10/scripts/run_lint.sh` | PASS (TB waivers documented) |
| Formal bmc | `sh design/amd_am26xx/members/am26s10/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26s10/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26s10/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26s10/scripts/run_sim.sh` | PASS — `am26s10 TEST PASSED (35 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26s10/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation: exhaustive 32-combination sweep with pull-up bias
  (enabled rows: B̄ = !I, Z̄ = !B̄; released rows: bus idles high and
  receivers read it), plus the directed party-line section — two
  instances on one biased bus, drive/handover/release — on both
  simulators.
- Formal: driver contract and release on the driver-role ports,
  receiver contract with harness-driven bus; covers reach every
  truth-table row class plus all-driven/all-released states.

## Scope and limits

- Bus pins are modeled with split driver/receiver ports (verification-
  flow accommodation, documented in the spec's port-structure note);
  the tie, bias and party-line resolution are simulation-directed
  because Yosys formal has no pull-up primitive and rejects inout
  directionality in the SMT2 backend. A Verilator toolchain note:
  weak-strength continuous assignments (`assign (weak1,weak0)`) are
  mis-resolved by Verilator 5.052 and were replaced by `pullup`
  primitives in the testbench.
- Electrical envelope (sink capability, switching points, loading,
  delays) is documented, not modeled.
- No RTL lint waivers; the TB waivers are listed in the plan.
