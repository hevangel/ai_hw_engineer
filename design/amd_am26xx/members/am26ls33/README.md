# AMD Am26LS33: quad differential line receiver

The Am26LS33 shares the [Am26LS32](../am26ls32/README.md)'s logic
diagram, pin map, 3-state outputs, OR-ed complementary enable pair and
fail-safe relationship ("output always high when inputs are open"), but
carries the wider-range electrical envelope: ±500 mV input sensitivity
over the ±15 V input voltage range, where the LS32 is ±200 mV over ±7 V.
Same 1979 datasheet page (4-40 to 4-44), two distinct physical parts
with distinct member issues.

First introduced: **1977*** — documented in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
alongside the LS32; reprinted in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf).
The bound is retained rather than guessed.

Why it matters here: it is the family's documented example of two
parts sharing one logic diagram while differing in analog envelope —
the digital contract is identical, so the reconstruction keeps a
separate source file and verifies it independently while the specs
cross-reference the shared sheet and the assumption ledger records the
sensitivity difference as electrical-only.

This reconstruction implements the documented digital contract as a
zero-delay combinational block, per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 1024-
combination simulation in Verilator and xezim (including the exact
`z` state), and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26ls33/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#199](https://github.com/hevangel/ai_hw_engineer/issues/199);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
