# Am26LS29 verification report

All commands run inside `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3, z3 via SMTBMC)
from the repository root.

| Flow | Command | Result |
|---|---|---|
| Lint | `sh design/amd_am26xx/members/am26ls29/scripts/run_lint.sh` | PASS (no waivers) |
| Formal bmc | `sh design/amd_am26xx/members/am26ls29/scripts/run_formal.sh bmc` | PASS, depth 2 (exhaustive for combinational logic) |
| Formal prove | `sh design/amd_am26xx/members/am26ls29/scripts/run_formal.sh prove` | PASS (unbounded) |
| Formal cover | `sh design/amd_am26xx/members/am26ls29/scripts/run_formal.sh cover` | PASS, all covers reached |
| Simulation | `sh design/amd_am26xx/members/am26ls29/scripts/run_sim.sh` | PASS — `am26ls29 TEST PASSED (64 checks)`, Verilator and xezim |
| Synthesis | `sh design/amd_am26xx/members/am26ls29/scripts/run_synth.sh` | PASS — Yosys `check -assert` clean |

## Evidence detail

- Simulation sweeps data × enable × slew-pin toggling (64 checks) with
  exact `z` assertions, proving the enable contract and the slew-pin
  boolean independence together, on both simulators.
- Formal asserts enable semantics and slew independence in every
  state; covers reach disabled, per-driver enabled, mixed and slew-
  independence states.

## Scope and limits

- Zero-delay combinational reconstruction; the RS-423 output swing,
  slew-rate figures, three-state enable/disable times, line drive and
  short-circuit protection are documented in the spec, not modeled.
- No RTL lint waivers required.
