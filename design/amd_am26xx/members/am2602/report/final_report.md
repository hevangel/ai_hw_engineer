# Am2602 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2602/scripts/run_lint.sh` | PASS (documented RTL waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2602/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am2602/scripts/run_formal.sh prove` | PASS (unbounded safety properties) |
| Formal cover | `sh design/amd_am26xx/members/am2602/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am2602/scripts/run_sim.sh` | PASS — `am2602 TEST PASSED`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2602/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation covers both Table I trigger rows per channel from
  quiescence, the non-trigger combinations (held-high network, falling
  network edges, toggles under a held-high network), exact pulse width,
  retrigger extension, asynchronous clear dominance with spike
  suppression, consumed-edge semantics, and channel independence (both
  channels running; channel 2 cleared mid-run). Both simulators report
  the identical checks passing.
- Formal bmc/cover verify both channels against independent reference
  models; prove carries complementarity and clear dominance unbounded.

## Scope and limits

- Pulse width is the parameterized `PULSE_CYCLES` (4) reference cycles;
  the RC law and the low-power electrical parameters are documented, not
  modeled.
- Formal scoping mirrors the family plan: bounded behavioral equivalence
  (exhaustive at depth 24 for this parameterization), unbounded safety
  properties.
- Documented localized lint waivers in `src/am2602.sv`:
  `SYNCASYNCNET` (intentional synchronous sampling of the async clear
  pin) and `PROCASSINIT` (quiescent power-up initializers).
- Power-up state is a modeling assumption (the physical part has no
  reset pin and specifies no power-up state).
