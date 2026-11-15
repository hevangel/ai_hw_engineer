# Am26S02 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26s02/scripts/run_lint.sh` | PASS (documented RTL waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26s02/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am26s02/scripts/run_formal.sh prove` | PASS (unbounded safety properties) |
| Formal cover | `sh design/amd_am26xx/members/am26s02/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26s02/scripts/run_sim.sh` | PASS — `am26s02 TEST PASSED`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26s02/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- The contract was qualified across the 1974 preliminary sheet and the
  1978 final printing: both function tables agree, so the RTL, tests and
  properties encode one digital contract with the documented electrical
  envelope in the spec ledger.
- Simulation runs the family stimulus plan (both trigger rows per
  channel, non-trigger combinations, pulse width, retrigger, async clear
  dominance, consumed edges, channel independence) on both simulators.
- Formal bmc/cover verify both channels against independent reference
  models; prove carries complementarity and clear dominance unbounded.

## Scope and limits

- Pulse width is the parameterized `PULSE_CYCLES` (4) reference cycles;
  the Schottky RC laws (including the 1978 protected-capacitor
  equations), the clear-recovery time and the 20 ns minimum trigger
  width are documented stimulus boundaries, not modeled behavior.
- Formal scoping mirrors the family plan.
- Documented localized lint waivers in `src/am26s02.sv`: `SYNCASYNCNET`
  and `PROCASSINIT`.
- Power-up state is a modeling assumption.
