# Am2600 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2600/scripts/run_lint.sh` | PASS (RTL no waivers; TB with documented waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2600/scripts/run_formal.sh bmc` | PASS, depth 24 |
| Formal prove | `sh design/amd_am26xx/members/am2600/scripts/run_formal.sh prove` | PASS (unbounded, induction-stable properties) |
| Formal cover | `sh design/amd_am26xx/members/am2600/scripts/run_formal.sh cover` | PASS, all 10 covers reached |
| Simulation | `sh design/amd_am26xx/members/am2600/scripts/run_sim.sh` | PASS — `am2600 TEST PASSED: 89 checks`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2600/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exercises every Table I trigger row from quiescence, the
  gated non-trigger combinations, the exact PULSE_CYCLES pulse width,
  retrigger extension, asynchronous termination by either clear pin,
  spike suppression under a held clear, and consumed-edge semantics; both
  simulators report the same 89 checks passing.
- Formal bmc/cover verify the DUT against an independently written
  reference model in every explored state and reach every documented
  behavior cover; prove carries the induction-stable complementarity and
  clear-dominance properties unbounded.

## Scope and limits

- The pulse width is the parameterized `PULSE_CYCLES` (4) reference
  cycles, not the RC law; the electrical contract is documented in the
  spec assumption ledger.
- Formal scoping: mirror equality and pulse-width properties are bounded
  (bmc/cover at depth 24, exhaustive for the five-cycle observable
  history of this parameterization); prove is unbounded for
  complementarity and clear dominance. Recorded in `plans/formal_plan.md`.
- One localized `SYNCASYNCNET` lint waiver in `src/am2600.sv` documents
  the intentional synchronous sampling of the asynchronous clear pin.
- Power-up state is a modeling assumption (the physical part has no reset
  pin and specifies no power-up state).
