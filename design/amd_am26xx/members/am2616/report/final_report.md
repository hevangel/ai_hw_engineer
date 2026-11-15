# Am2616 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am2616/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am2616/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am2616/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am2616/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am2616/scripts/run_sim.sh` | PASS — `am2616 TEST PASSED (256 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am2616/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation exhaustively checks all 256 input combinations against
  the four per-driver contracts on both simulators.
- Formal asserts the contract, inhibit dominance and inhibit-low data
  path in every state; covers reach the inhibited (mark), transmitting
  and all-inhibited states.

## Scope and limits

- Zero-delay combinational reconstruction; the RS-232C/MIL-188C
  electrical conventions (swing from VCC/VEE, slew-rate limiting,
  short-circuit protection, output impedance, delay) are documented in
  the spec, not modeled.
- No RTL lint waivers required.
