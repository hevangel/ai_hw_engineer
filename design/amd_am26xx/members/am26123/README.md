# AMD Am26123: dual retriggerable resettable monostable multivibrator

The Am26123 is AMD's improved Am54/74123-compatible dual one-shot: the
same 16-pin arrangement (A active low, B active high, CLEAR active low
per monostable) with two documented improvements — ±1% pulse-width
stability over temperature and an output latch that gives "immunity to
spurious output changes in the quiescent state due to coupling of
external noise at the timing capacitor nodes". The pulse range is 45 ns
to ∞.

First introduced: **1974*** — documented in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-87 to 4-92, truth table page 4-91); the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
selection guide (page 1-13) repeats the Δtpw guarantee. No earlier dated
AMD documentation is located; the bound is retained rather than guessed.

Why it matters here: it is the documented AMD counterpart of the
ubiquitous 74123 board-logic one-shot, with a fully specified
truth-table trigger network (A and B in an AND gate), and it anchors the
low-power [Am26L123](../am26l123/README.md) member whose datasheet
contract is defined by the 1979 selection guide as "Low-Power version
26123".

This reconstruction implements the documented digital contract with a
parameterized pulse width standing in for the external RC network, per
the [specification](spec/spec.md) and its assumption ledger.

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
sh design/amd_am26xx/members/am26123/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#192](https://github.com/hevangel/ai_hw_engineer/issues/192);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
