# Am26123 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26123/scripts/run_lint.sh` | PASS (documented RTL waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26123/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am26123/scripts/run_formal.sh prove` | PASS (unbounded safety properties) |
| Formal cover | `sh design/amd_am26xx/members/am26123/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26123/scripts/run_sim.sh` | PASS — `am26123 TEST PASSED`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26123/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation covers every truth-table row per channel (trigger paths
  B↑ with A low and A↓ with B high; the non-trigger rows), exact pulse
  width, retrigger extension, asynchronous clear dominance with spike
  suppression and consumed-edge semantics, and channel independence.
  Both simulators pass.
- Formal bmc/cover verify both channels against independent reference
  models; prove carries complementarity and clear dominance unbounded.

## Scope and limits

- Pulse width is the parameterized `PULSE_CYCLES` (4) reference cycles;
  the RC timing laws, the 45 ns minimum and the output latch are
  documented, not modeled.
- Formal scoping mirrors the family plan.
- Documented localized lint waivers in `src/am26123.sv`: `SYNCASYNCNET`
  and `PROCASSINIT`.
- Power-up state is a modeling assumption.
