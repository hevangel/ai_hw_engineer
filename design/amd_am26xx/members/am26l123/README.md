# AMD Am26L123: low-power dual retriggerable resettable monostable

The Am26L123 is the low-power grade of AMD's 74123-compatible dual
one-shot. The located sources document it through the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
monostable selection guide (printed page 1-13): "Low-Power version
26123, tpw = 120 ns to ∞", with the same Dual/Retriggerable/Resettable
behavior flags as the Am26123. No dedicated Am26L123 datasheet page
exists in the located 1977–1979 AMD data books, so the functional
contract here is the Am26123 truth table composed with the selection
guide's electrical envelope — a composition recorded explicitly in the
specification's assumption ledger rather than silently substituted.

First introduced: **1979*** — the 1979 selection guide is the earliest
located dated AMD documentation naming the part (the 1977 and 1978 data
books do not list it); the bound is retained rather than guessed.

Why it matters here: it completes AMD's documented speed/power grading
of the 26123 one-shot (alongside the
[Am26123](../am26123/README.md)) and is the family member whose
contract requires source composition — exactly the case the parent
issue's assumption-ledger requirement exists for.

This reconstruction implements the composed digital contract with a
parameterized pulse width standing in for the external RC network, per
the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover with per-channel
independent reference models and reachable covers, directed simulation in
Verilator and xezim, and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26l123/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#194](https://github.com/hevangel/ai_hw_engineer/issues/194);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
