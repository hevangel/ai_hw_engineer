# AMD Am26S11: quad open-collector bus transceiver (non-inverting)

The Am26S11 is the non-inverting sibling of the
[Am26S10](../am26s10/README.md): the same 16-pin open-collector bus
transceiver with the same always-active inverting receivers, but the
driver passes the input through — the truth table gives B̄ = I when
enabled, against the S10's B̄ = !I — so the two parts let a board pick
the bus polarity per channel direction without changing the layout.

First introduced: **1974*** — documented on the shared Am26S10 ·
Am26S11 sheet in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(truth tables page 4-41) and reprinted in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-57 to 4-61). No earlier dated AMD documentation is located;
the bound is retained rather than guessed.

Why it matters here: the S10/S11 pair is the documented example of a
polarity-graded bus part in this family — one digital difference
(driver polarity) on an otherwise identical contract — and its
reconstruction verifies that difference independently against the
published truth tables.

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
sh design/amd_am26xx/members/am26s11/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#202](https://github.com/hevangel/ai_hw_engineer/issues/202);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
