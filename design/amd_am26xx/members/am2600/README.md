# AMD Am2600: retriggerable monostable multivibrator

The Am2600 is AMD's single DC-level-sensitive retriggerable one-shot: five
trigger inputs (two active-low, three active-high) combine into one
trigger network whose rising edge starts a timing cycle of a width set by
an external RC network, and two independent active-low direct clears can
terminate or inhibit a cycle at any time.

First introduced: **1974*** — the earliest located dated AMD documentation
is the [1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf) itself
(catalog pages 4-15 to 4-20), where the part appears alongside its Am9600
and Am9601 siblings of AMD's early 93xx/96xx MSI interface generation;
availability may precede the book and the bound is retained rather than
guessed.

Why it matters here: the Am2600/9600/9601 line is AMD's entry into the
line/interface market documented in the same 1974 book as the Am25xx logic
family, and its trigger-network truth table (active-low inputs OR'd, then
gated with three active-high inputs) is a compact, fully specified
combinational contract — the family member that pins down the one-shot
digital abstraction reused by the dual Am2602/Am26L02/Am26S02/Am26123
members.

This reconstruction implements the documented digital contract: the
trigger truth table, the dual clears with inhibit-while-cleared
semantics, retriggering independent of the running state, and a
parameterized pulse width standing in for the RC network. Electrical
behavior (RC pins, stray-capacitance limits, propagation delays) is
documented in the [specification](spec/spec.md), not modeled.

**Verified.** Verilator lint, formal bmc/prove/cover with an independent
reference model and reachable covers, directed simulation in Verilator and
xezim, and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am2600/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#186](https://github.com/hevangel/ai_hw_engineer/issues/186);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
