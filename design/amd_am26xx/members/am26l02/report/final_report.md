# Am26L02 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26l02/scripts/run_lint.sh` | PASS (documented RTL waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26l02/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am26l02/scripts/run_formal.sh prove` | PASS (unbounded safety properties) |
| Formal cover | `sh design/amd_am26xx/members/am26l02/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26l02/scripts/run_sim.sh` | PASS — `am26l02 TEST PASSED`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26l02/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation runs the full Am2602 stimulus plan (identical published
  truth table): both trigger rows per channel, non-trigger combinations,
  exact pulse width, retrigger extension, asynchronous clear dominance,
  consumed edges, and channel independence. Both simulators pass.
- Formal bmc/cover verify both channels against independent reference
  models; prove carries complementarity and clear dominance unbounded;
  all covers reached.

## Scope and limits

- Pulse width is the parameterized `PULSE_CYCLES` (4) reference cycles;
  the low-power RC law (0.33 coefficient, 3.2 term), Rx range and
  100 ns minimum pulse are documented, not modeled.
- Formal scoping mirrors the family plan.
- Documented localized lint waivers in `src/am26l02.sv`: `SYNCASYNCNET`
  and `PROCASSINIT`.
- Power-up state is a modeling assumption.
