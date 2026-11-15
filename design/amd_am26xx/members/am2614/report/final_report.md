# Am2614 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2614/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2614/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am2614/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am2614/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am2614/scripts/run_sim.sh` | PASS — `am2614 TEST PASSED (1024 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2614/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exhaustively checks all 1024 input combinations against
  the four per-driver NAND contracts on both simulators.
- Formal asserts the NAND contract and the strobe-idle property in every
  state (combinational, so bmc/prove are exhaustive/unbounded by
  construction) and reaches every documented behavior cover.

## Scope and limits

- Zero-delay combinational reconstruction; electrical behavior
  (propagation delays, active pull-up impedance, short-circuit
  current, input clamps) is documented in the spec, not modeled.
- No RTL lint waivers required.
