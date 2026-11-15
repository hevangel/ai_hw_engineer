# AMD Am26S10: quad open-collector bus transceiver (inverting)

The Am26S10 is AMD's Schottky quad bus transceiver for party-line
operation: four open-collector inverting bus drivers (100 mA sink at
0.8 V max) behind one active-low enable, and four separate
always-active inverting bus receivers tied to the same bus nodes — the
truth table says it directly: drive rows give B̄ = !I, the released
rows give B̄ = Y (the level another transceiver or the pull-up sets)
and the receiver keeps driving Z̄ = Ȳ regardless. Bus-compatible with
the Am2905/2906/2907 party-line family.

First introduced: **1974*** — documented in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-39 to 4-44, truth tables page 4-41) and reprinted
identically in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-57 to 4-61). No earlier dated AMD documentation is located;
the bound is retained rather than guessed.

Why it matters here: its open-collector contract — release rather than
three-state-drive, with the receiver reading the released bus — is a
distinct bus convention from the three-state LS drivers/receivers of
this family, and the physical pin serves two roles that the
reconstruction verifies through a documented port-role split (see the
spec) because the simulation and formal flows differ in tristate
support.

This reconstruction implements the documented digital contract per the
[specification](spec/spec.md); the electrical envelope is documented,
not modeled.

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive
simulation plus directed party-line checks in Verilator and xezim, and
Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26s10/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#201](https://github.com/hevangel/ai_hw_engineer/issues/201);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
