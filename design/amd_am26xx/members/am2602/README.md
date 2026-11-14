# AMD Am2602: dual retriggerable resettable monostable multivibrator

The Am2602 packages two independent DC-level-sensitive retriggerable
one-shots in one 16-pin part. Each monostable triggers on Ī0 falling (with
I1 low) or I1 rising (with Ī0 high) — the datasheet's single-bubble OR
gate — and an active-low direct clear terminates or inhibits a cycle at
any time. "Retriggerable 0 to 100% duty cycle", "50 ns to ∞ output pulse
width range"; the Am2602 is the selected-speed version of the Am9602 with
a guaranteed pulse-width change under 1% over 0 °C to +75 °C.

First introduced: **1974*** — the earliest located dated AMD documentation
is the [1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-21 to 4-26); the Am9602 sibling belongs to AMD's early
9600-series interface generation and availability may precede the book.
The bound is retained rather than guessed.

Why it matters here: it is the two-channel arrangement and pin map that
the Am26L02 (low power) and Am26S02 (Schottky) reuse unchanged, and its
trigger-pair polarity (one active-low, one active-high input per
monostable) is the documented contract reused across those members; the
[Am2600](../am2600/README.md) is the single-channel sibling in the same
data book.

This reconstruction implements the documented digital contract: both
trigger rows, reset dominance with inhibit-while-cleared semantics,
retriggering independent of the running state, and a parameterized pulse
width standing in for the RC network, per the
[specification](spec/spec.md) and its assumption ledger.

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
sh design/amd_am26xx/members/am2602/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#187](https://github.com/hevangel/ai_hw_engineer/issues/187);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
