# Am26L123 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26l123/scripts/run_lint.sh` | PASS (documented RTL waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26l123/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am26l123/scripts/run_formal.sh prove` | PASS (unbounded safety properties) |
| Formal cover | `sh design/amd_am26xx/members/am26l123/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26l123/scripts/run_sim.sh` | PASS — `am26l123 TEST PASSED`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26l123/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- The contract is a documented composition: the 1979 selection guide
  defines the part as the low-power Am26123, and the digital function is
  the Am26123's published truth table. The stimulus plan and formal
  properties therefore mirror the verified am26123 member, run
  independently against this source file on both simulators.
- Formal bmc/cover verify both channels against independent reference
  models; prove carries complementarity and clear dominance unbounded.

## Scope and limits

- Source composition is recorded in the spec assumption ledger: no
  dedicated Am26L123 datasheet page exists in the located sources; the
  120 ns minimum pulse and low-power electricals are documented, not
  modeled.
- Pulse width is the parameterized `PULSE_CYCLES` (4) reference cycles.
- Formal scoping mirrors the family plan.
- Documented localized lint waivers in `src/am26l123.sv`:
  `SYNCASYNCNET` and `PROCASSINIT`.
- Power-up state is a modeling assumption.
